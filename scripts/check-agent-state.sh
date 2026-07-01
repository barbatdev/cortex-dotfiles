#!/bin/sh
set -eu

ROOT_DIR=$(unset CDPATH; cd -- "$(dirname -- "$0")/.." && pwd)
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
assert "pane report-metadata pane-smoke --source cortex.agent-state --custom-status Working: smoke test --state-label working=Working --agent smoke-agent --display-agent smoke-agent" in log
PY
"$CMD" list | python3 -c 'import sys; data=sys.stdin.read(); assert "smoke-agent" in data and "fresh" in data'
"$CMD" get --agent smoke-agent | python3 -c 'import json,sys; rec=json.load(sys.stdin); assert rec["schema"] == "cortex.agent_state.v1"; assert rec["context"]["pane_id"] == "pane-smoke"'
env HERDR_ENV= CORTEX_MULTIPLEXER=herdr "$CMD" report --source smoke --agent mux-agent --state working --message "mux test" >/dev/null
python3 - "$HERDR_FAKE_LOG" <<'PY'
import pathlib
import sys

log = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
assert "pane report-metadata pane-smoke --source cortex.agent-state --custom-status Working: mux test --state-label working=Working --agent mux-agent --display-agent mux-agent" in log
PY
"$CMD" report --source smoke --agent safe-agent --state blocked --message "line1
line2	$(printf '\001')$(python3 -c 'print("x" * 260)')" >/dev/null
"$CMD" list | python3 -c 'import sys; rows=sys.stdin.read().splitlines(); row=next(r for r in rows if "safe-agent" in r); message=row.split("\t", 5)[5]; assert message.startswith("line1line2") and len(message) == 240 and "\t" not in message'
python3 - "$XDG_STATE_HOME" <<'PY'
import json
import pathlib
import sys

current = pathlib.Path(sys.argv[1]) / "cortex" / "agent-state" / "current"
(current / "bad.json").write_text("{not json", encoding="utf-8")
(current / "missing-expires.json").write_text(json.dumps({
    "source": {"adapter": "bad"},
    "agent": {"agent_id": "missing-expires"},
    "state": "working",
    "message": "bad\nmessage",
}), encoding="utf-8")
(current / "wrong-shape.json").write_text(json.dumps({
    "source": "bad",
    "agent": "bad",
    "context": "bad",
    "state": 7,
    "message": "bad\tmessage",
}), encoding="utf-8")
PY
"$CMD" list | python3 -c 'import sys; data=sys.stdin.read(); assert "missing-expires" in data and "unknown" in data'
before=$(wc -l <"$HERDR_FAKE_LOG")
CORTEX_AGENT_STATE_HERDR=0 "$CMD" report --source smoke --agent disabled-agent --state working --message "disabled" >/dev/null
after=$(wc -l <"$HERDR_FAKE_LOG")
test "$before" = "$after"
"$CMD" get --agent disabled-agent | python3 -c 'import json,sys; rec=json.load(sys.stdin); assert rec["state"] == "working"'
"$CMD" clear >/dev/null
"$CMD" list | python3 -c 'import sys; assert "no agent states" in sys.stdin.read()'

printf '%s\n' "agent-state smoke ok"
