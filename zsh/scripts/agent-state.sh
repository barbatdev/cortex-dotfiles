#!/bin/sh

# Minimal local reporter for the cortex.agent_state.v1 contract.
cortex_agent_state() {
    if ! command -v python3 >/dev/null 2>&1; then
        printf '%s\n' "agent-state: python3 is required" >&2
        return 127
    fi

    python3 - "$@" <<'PY'
import argparse
import hashlib
import json
import os
import shutil
import sys
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

SCHEMA = "cortex.agent_state.v1"
VALID_STATES = {"working", "blocked", "idle", "unknown"}


def now_utc():
    return datetime.now(timezone.utc)


def parse_time(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def format_time(value):
    return value.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def state_root():
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
    return Path(base) / "cortex" / "agent-state"


def paths():
    root = state_root()
    return root, root / "events.jsonl", root / "current"


def current_key(source, agent, pane_id):
    raw = "\0".join([source, agent, pane_id or ""])
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def default_ttl(state):
    if state in {"working", "blocked"}:
        return 120
    if state == "idle":
        return 3600
    return 60


def build_event(args):
    if args.state not in VALID_STATES:
        raise SystemExit(f"invalid state: {args.state}")

    observed_at = now_utc()
    expires_at = observed_at + timedelta(seconds=args.ttl or default_ttl(args.state))
    pane_id = os.environ.get("HERDR_PANE_ID")
    session_id = os.environ.get("HERDR_SESSION")
    workspace_id = os.environ.get("HERDR_WORKSPACE_ID")

    context = {}
    if pane_id:
        context["pane_id"] = pane_id
    if session_id:
        context["session_id"] = session_id
    if workspace_id:
        context["workspace_id"] = workspace_id

    event = {
        "schema": SCHEMA,
        "event_id": str(uuid.uuid4()),
        "state": args.state,
        "source": {"adapter": args.source},
        "agent": {"agent_id": args.agent, "display_name": args.agent},
        "context": context,
        "observed_at": format_time(observed_at),
        "expires_at": format_time(expires_at),
    }
    if args.message:
        event["message"] = args.message
    return event


def write_json_atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, sort_keys=True, separators=(",", ":"))
        handle.write("\n")
    tmp.replace(path)


def cmd_report(args):
    root, events_path, current_dir = paths()
    root.mkdir(parents=True, exist_ok=True)
    current_dir.mkdir(parents=True, exist_ok=True)

    event = build_event(args)
    with events_path.open("a", encoding="utf-8") as handle:
        json.dump(event, handle, sort_keys=True, separators=(",", ":"))
        handle.write("\n")

    pane_id = event.get("context", {}).get("pane_id")
    key = current_key(event["source"]["adapter"], event["agent"]["agent_id"], pane_id)
    write_json_atomic(current_dir / f"{key}.json", event)
    print(f"reported {event['state']} {event['agent']['agent_id']}")


def iter_current():
    _, _, current_dir = paths()
    if not current_dir.exists():
        return []
    records = []
    for path in sorted(current_dir.glob("*.json")):
        try:
            records.append(json.loads(path.read_text(encoding="utf-8")))
        except (OSError, json.JSONDecodeError):
            continue
    return records


def stale_label(record, current_time):
    expires_at = parse_time(record["expires_at"])
    if expires_at <= current_time:
        return "stale"
    return "fresh"


def cmd_list(_args):
    records = iter_current()
    current_time = now_utc()
    if not records:
        print("no agent states")
        return

    print("SOURCE\tAGENT\tSTATE\tSTALE\tPANE\tMESSAGE")
    for record in records:
        context = record.get("context", {})
        print("\t".join([
            record.get("source", {}).get("adapter", ""),
            record.get("agent", {}).get("agent_id", ""),
            record.get("state", "unknown"),
            stale_label(record, current_time),
            context.get("pane_id", ""),
            record.get("message", ""),
        ]))


def cmd_get(args):
    matches = []
    for record in iter_current():
        if args.agent and record.get("agent", {}).get("agent_id") != args.agent:
            continue
        if args.source and record.get("source", {}).get("adapter") != args.source:
            continue
        matches.append(record)

    if not matches:
        print("agent state not found", file=sys.stderr)
        return 1
    for record in matches:
        print(json.dumps(record, sort_keys=True))
    return 0


def cmd_clear(_args):
    root, events_path, current_dir = paths()
    if current_dir.exists():
        shutil.rmtree(current_dir)
    root.mkdir(parents=True, exist_ok=True)
    events_path.write_text("", encoding="utf-8")
    print("cleared agent states")


def main(argv):
    parser = argparse.ArgumentParser(prog="cortex.agent_state.v1")
    sub = parser.add_subparsers(dest="command", required=True)

    report = sub.add_parser("report", help="record a current agent state")
    report.add_argument("--source", required=True, help="adapter identity")
    report.add_argument("--agent", required=True, help="logical agent identity")
    report.add_argument("--state", required=True, choices=sorted(VALID_STATES))
    report.add_argument("--message", help="short caller-provided display message")
    report.add_argument("--ttl", type=int, help="seconds until the state is stale")
    report.set_defaults(func=cmd_report)

    list_cmd = sub.add_parser("list", help="list current states")
    list_cmd.set_defaults(func=cmd_list)

    get = sub.add_parser("get", help="print current state records as JSON")
    get.add_argument("--agent", help="filter by logical agent identity")
    get.add_argument("--source", help="filter by source adapter")
    get.set_defaults(func=cmd_get)

    clear = sub.add_parser("clear", help="clear current state and local event log")
    clear.set_defaults(func=cmd_clear)

    args = parser.parse_args(argv)
    result = args.func(args)
    return 0 if result is None else result


raise SystemExit(main(sys.argv[1:]))
PY
}

if [ "${0##*/}" = "agent-state.sh" ] && [ -z "${ZSH_EVAL_CONTEXT:-}" ]; then
    cortex_agent_state "$@"
fi
