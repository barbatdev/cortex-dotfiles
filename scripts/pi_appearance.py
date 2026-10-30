#!/usr/bin/env python3
"""Merge the RefactorIA appearance keys into Pi's settings.json.

Usage: pi_appearance.py SOURCE TARGET [--dry-run]

Pi owns settings.json (packages, models, per-machine options), so it is never
replaced: only the keys in SOURCE are set, every other key keeps its value
and order, and the file keeps its permissions. A malformed TARGET is left
untouched and reported. An absent TARGET is created with the SOURCE keys.
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
from pathlib import Path


def load(path: Path, label: str) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"pi_appearance: malformed {label}: {path} ({exc})") from exc
    if not isinstance(value, dict):
        raise SystemExit(f"pi_appearance: malformed {label}: {path} (not a JSON object)")
    return value


def write_atomic(path: Path, data: dict, mode: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=f"{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def main(argv: list[str]) -> int:
    args = [a for a in argv if a != "--dry-run"]
    dry_run = len(args) != len(argv)
    if len(args) != 2:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    source, target = Path(args[0]), Path(args[1])
    keys = load(source, "source")

    try:
        current = load(target, "settings") if target.exists() else {}
    except SystemExit as exc:
        print(exc, file=sys.stderr)
        return 1
    mode = (target.stat().st_mode & 0o777) if target.exists() else 0o600

    merged = {**current, **keys}
    if merged == current and target.exists():
        print(f"  = {target} already has the RefactorIA appearance")
        return 0
    changed = ", ".join(k for k in keys if current.get(k) != keys[k])
    if dry_run:
        print(f"  → Would set {changed} in {target}")
        return 0
    write_atomic(target, merged, mode)
    print(f"  ✓ {target} updated: {changed}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
