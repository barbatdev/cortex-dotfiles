#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_STATE=$(mktemp -d)
trap 'rm -rf "$TMP_STATE"' EXIT INT TERM

CMD="$ROOT_DIR/zsh/scripts/agent-state.sh"
export XDG_STATE_HOME="$TMP_STATE"
export HERDR_PANE_ID="pane-smoke"
export HERDR_SESSION="session-smoke"
export HERDR_WORKSPACE_ID="workspace-smoke"

"$CMD" report --source smoke --agent smoke-agent --state working --message "smoke test" >/dev/null
"$CMD" list | python3 -c 'import sys; data=sys.stdin.read(); assert "smoke-agent" in data and "fresh" in data'
"$CMD" get --agent smoke-agent | python3 -c 'import json,sys; rec=json.load(sys.stdin); assert rec["schema"] == "cortex.agent_state.v1"; assert rec["context"]["pane_id"] == "pane-smoke"'
"$CMD" clear >/dev/null
"$CMD" list | python3 -c 'import sys; assert "no agent states" in sys.stdin.read()'

printf '%s\n' "agent-state smoke ok"
