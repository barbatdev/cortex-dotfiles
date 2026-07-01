#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_STATE=$(mktemp -d)
TMP_BIN=$(mktemp -d)
trap 'rm -rf "$TMP_STATE" "$TMP_BIN"' EXIT INT TERM

CMD="$ROOT_DIR/zsh/scripts/agent-state.sh"
export XDG_STATE_HOME="$TMP_STATE"
export PATH="$TMP_BIN:$PATH"
export HERDR_PANE_ID="pane-smoke"
export HERDR_ENV="1"
export HERDR_SESSION="session-smoke"
export HERDR_WORKSPACE_ID="workspace-smoke"
export HERDR_FAKE_LOG="$TMP_STATE/herdr.log"

cat >"$TMP_BIN/herdr" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$HERDR_FAKE_LOG"
EOF
chmod +x "$TMP_BIN/herdr"

"$CMD" report --source smoke --agent smoke-agent --state working --message "smoke test" >/dev/null
python3 - "$HERDR_FAKE_LOG" <<'PY'
import pathlib
import sys

log = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
assert "pane report-agent pane-smoke --source cortex.agent-state --agent smoke-agent --state working --message smoke test" in log
PY
"$CMD" list | python3 -c 'import sys; data=sys.stdin.read(); assert "smoke-agent" in data and "fresh" in data'
"$CMD" get --agent smoke-agent | python3 -c 'import json,sys; rec=json.load(sys.stdin); assert rec["schema"] == "cortex.agent_state.v1"; assert rec["context"]["pane_id"] == "pane-smoke"'
before=$(wc -l <"$HERDR_FAKE_LOG")
CORTEX_AGENT_STATE_HERDR=0 "$CMD" report --source smoke --agent disabled-agent --state working --message "disabled" >/dev/null
after=$(wc -l <"$HERDR_FAKE_LOG")
test "$before" = "$after"
"$CMD" get --agent disabled-agent | python3 -c 'import json,sys; rec=json.load(sys.stdin); assert rec["state"] == "working"'
"$CMD" clear >/dev/null
"$CMD" list | python3 -c 'import sys; assert "no agent states" in sys.stdin.read()'

printf '%s\n' "agent-state smoke ok"
