#!/usr/bin/env python3
"""Sync the versioned gentle-pi model profiles into each Pi home.

Source of truth: pi/gentle-ai/profiles.json (the gentle-pi
`agent_model_profiles` store, without the machine-local `current` snapshot).

For every home (default: ~/.pi and ~/.gentle-shell) that has an `agent/` dir:
  1. Merge the repo profiles into <home>/gentle-ai/profiles.json. Repo profiles
     replace same-name local ones; local-only profiles and `current` are kept.
     The local `active` profile is kept when it still exists. A home without a
     store starts on the empty `current` profile, so its routing is untouched.
  2. Materialize the active profile the way gentle-pi does, so the routing is
     live without opening /gentle:profiles:
       - orchestrator -> agent/settings.json defaultProvider/defaultModel/defaultThinkingLevel
       - each agent   -> agent/subagents.json model_profiles.<agent> {model, effort}
                         and agent/agents/<agent>.md frontmatter model/thinking

Every changed file is backed up as <file>.bak-profiles-<timestamp> and written
atomically. Running it twice changes nothing.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import time
from pathlib import Path

ORCHESTRATOR = "orchestrator"
STAMP = time.strftime("%Y%m%dT%H%M%S")


def load_json(path: Path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text())


def write_if_changed(path: Path, text: str, dry_run: bool, changes: list[str]) -> None:
    old = path.read_text() if path.exists() else None
    if old == text:
        return
    changes.append(str(path))
    if dry_run:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if old is not None:
        shutil.copy2(path, f"{path}.bak-profiles-{STAMP}")
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text)
    if old is not None:
        os.chmod(tmp, path.stat().st_mode & 0o777)
    os.replace(tmp, path)


def dump(data) -> str:
    return json.dumps(data, indent=2) + "\n"


def merge_store(local: dict, repo: dict) -> dict:
    profiles = dict(local.get("profiles", {}))
    profiles.update(repo["profiles"])
    active = local.get("active")
    if not local:
        # A home that never used profiles keeps its current routing: start on
        # the empty `current` snapshot and let the person pick a profile.
        profiles.setdefault("current", {})
        active = "current"
    elif active not in profiles:
        active = repo["active"]
    return {"kind": repo["kind"], "version": repo["version"], "active": active, "profiles": profiles}


def set_frontmatter(text: str, key: str, value: str) -> str:
    match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not match:
        return text
    head = match.group(1)
    line = re.compile(rf"^{key}: .*$", re.M)
    head = line.sub(f"{key}: {value}", head) if line.search(head) else head
    return text[: match.start(1)] + head + text[match.end(1) :]


def materialize(agent_dir: Path, profile: dict, dry_run: bool, changes: list[str]) -> None:
    orch = profile.get(ORCHESTRATOR)
    if orch:
        settings_path = agent_dir / "settings.json"
        settings = load_json(settings_path, {})
        provider, _, model = orch["model"].partition("/")
        settings["defaultProvider"] = provider
        settings["defaultModel"] = model
        if orch.get("thinking"):
            settings["defaultThinkingLevel"] = orch["thinking"]
        write_if_changed(settings_path, dump(settings), dry_run, changes)

    sub_path = agent_dir / "subagents.json"
    sub = load_json(sub_path, {})
    profiles = sub.setdefault("model_profiles", {})
    for agent, entry in profile.items():
        if agent == ORCHESTRATOR:
            continue
        current = profiles.setdefault(agent, {})
        current["model"] = entry["model"]
        if entry.get("thinking"):
            current["effort"] = entry["thinking"]
        md = agent_dir / "agents" / f"{agent}.md"
        if md.exists():
            text = set_frontmatter(md.read_text(), "model", entry["model"])
            if entry.get("thinking"):
                text = set_frontmatter(text, "thinking", entry["thinking"])
            write_if_changed(md, text, dry_run, changes)
    write_if_changed(sub_path, dump(sub), dry_run, changes)


def sync_home(home: Path, repo: dict, dry_run: bool) -> list[str]:
    agent_dir = home / "agent"
    if not agent_dir.is_dir():
        return []
    changes: list[str] = []
    store_path = home / "gentle-ai" / "profiles.json"
    store = merge_store(load_json(store_path, {}), repo)
    write_if_changed(store_path, dump(store), dry_run, changes)
    active = store["profiles"][store["active"]]
    if active:
        materialize(agent_dir, active, dry_run, changes)
    return changes


def main(argv: list[str]) -> int:
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", type=Path, default=root / "pi" / "gentle-ai" / "profiles.json")
    parser.add_argument("--home", type=Path, action="append", help="Pi home (repeatable); default ~/.pi and ~/.gentle-shell")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    repo = json.loads(args.source.read_text())
    homes = args.home or [Path.home() / ".pi", Path.home() / ".gentle-shell"]
    for home in homes:
        changes = sync_home(home.expanduser(), repo, args.dry_run)
        verb = "would change" if args.dry_run else "changed"
        print(f"{home}: {verb} {len(changes)} file(s)")
        for change in changes:
            print(f"  {change}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
