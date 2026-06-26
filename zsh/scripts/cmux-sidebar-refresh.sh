#!/bin/bash

set -euo pipefail

TARGET_DIR="${1:-$PWD}"

realpath_portable() {
  local target="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$target"
  else
    python3 - <<'PY2' "$target"
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY2
  fi
}

json_value() {
  local key="$1"
  local fallback_key="${key##*.}"
  if command -v jq >/dev/null 2>&1; then
    jq -r ".$key // empty" 2>/dev/null
  else
    sed -n "s/.*\"$fallback_key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
  fi
}

TARGET_DIR=$(realpath_portable "$TARGET_DIR")
# No escribir active-workspace aquí: el único productor autorizado es cmux-focused-workspace.sh (T1).
# Esta función es consumidora del estado de sidebar; escribir el cache del caller generaba drift
# entre el workspace enfocado real y lo que mostraba la barra lateral.

CMUX_BIN=""
if command -v cmux >/dev/null 2>&1; then
  CMUX_BIN="cmux"
elif [ -x "/Applications/cmux.app/Contents/Resources/bin/cmux" ]; then
  CMUX_BIN="/Applications/cmux.app/Contents/Resources/bin/cmux"
else
  exit 0
fi

WORKSPACE_ID="${CMUX_WORKSPACE_ID:-}"
if [ -z "$WORKSPACE_ID" ]; then
  # env -u descarta el socket heredado del caller; cmux auto-descubre el socket vivo
  WORKSPACE_ID=$(env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" identify 2>/dev/null | json_value focused.workspace_id || true)
fi
[ -n "$WORKSPACE_ID" ] || exit 0

clear_status() {
  local key="$1"
  # env -u descarta el socket heredado del caller; cmux auto-descubre el socket vivo
  env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status "$key" "" >/dev/null 2>&1 || true
}

DIR_NAME=$(basename "$TARGET_DIR")

BRANCH=""
DIRTY=""
if git -C "$TARGET_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git -C "$TARGET_DIR" branch --show-current 2>/dev/null || true)
  if [[ -n $(git -C "$TARGET_DIR" status --porcelain 2>/dev/null) ]]; then
    DIRTY="*"
  fi
fi

AI_DIR="$TARGET_DIR/.ai"
SDD_MODE=""
SDD_SPEC=""
SDD_TASKS=""
SCRIPT_PATH=$(realpath_portable "${BASH_SOURCE[0]}")
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")/../../.." && pwd)"
RESUME_HELPER="$SCRIPT_DIR/scripts/sdd-helper.sh"
if [ ! -x "$RESUME_HELPER" ]; then
  RESUME_HELPER="${CORTEX_ROOT:-$HOME/cortex}/scripts/sdd-helper.sh"
fi

if [ -x "$RESUME_HELPER" ]; then
  RESUME_JSON=$("$RESUME_HELPER" sdd-resume-context.sh get "$TARGET_DIR" 2>/dev/null || true)
  if [ -n "$RESUME_JSON" ]; then
    RESUME_STATUS=$(printf '%s' "$RESUME_JSON" | json_value status)
    SDD_MODE=$(printf '%s' "$RESUME_JSON" | json_value execution_mode)

    case "$RESUME_STATUS" in
      ready)
        SDD_SPEC=$(printf '%s' "$RESUME_JSON" | json_value feature)
        TASK_FILE=$(printf '%s' "$RESUME_JSON" | json_value tasks_path)
        if [ -n "$TASK_FILE" ] && [ -f "$TARGET_DIR/$TASK_FILE" ]; then
          DONE=$(grep -c '^- \[x\]' "$TARGET_DIR/$TASK_FILE" 2>/dev/null || echo 0)
          PENDING=$(grep -c '^- \[ \]' "$TARGET_DIR/$TASK_FILE" 2>/dev/null || echo 0)
          SDD_TASKS="${DONE}/${PENDING}"
        fi
        ;;
      ambiguous_feature)
        SDD_SPEC="ambiguous"
        ;;
      incomplete_feature)
        SDD_SPEC="incomplete"
        ;;
    esac
  fi
fi

MCPS=""
BRAINS=""
if [ -f "$HOME/.config/opencode/opencode.json" ]; then
  MCPS=$(jq -r '.mcp // {} | to_entries[] | select(.value.enabled == true) | .key' "$HOME/.config/opencode/opencode.json" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  BRAINS=$(jq -r '.mcp // {} | to_entries[] | select(.value.enabled == true and (.key == "work-brain" or .key == "life-brain" or .key == "second-brain")) | .key' "$HOME/.config/opencode/opencode.json" 2>/dev/null \
    | sed 's/work-brain/work/; s/life-brain/life/; s/second-brain/notes/' \
    | tr '\n' ',' | sed 's/,$//')
fi

env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status project "$DIR_NAME" --icon "folder" --color "#89b4fa" >/dev/null 2>&1 || true

if [ -n "$BRANCH" ]; then
  env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status git_branch "$BRANCH$DIRTY" --icon "arrow.triangle.branch" --color "#a6adc8" >/dev/null 2>&1 || true
else
  clear_status git_branch
fi

if [ -n "$MCPS" ]; then
  env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status mcp "$MCPS" --icon "cpu" --color "#94e2d5" >/dev/null 2>&1 || true
else
  clear_status mcp
fi

if [ -n "$BRAINS" ]; then
  env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status brains "$BRAINS" --icon "brain.head.profile" --color "#89dceb" >/dev/null 2>&1 || true
else
  clear_status brains
fi

if [ -n "$SDD_MODE" ]; then
  if [ "$SDD_MODE" = "auto" ]; then
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status sdd_mode "$SDD_MODE" --icon "arrow.right.circle" --color "#a6e3a1" >/dev/null 2>&1 || true
  else
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status sdd_mode "$SDD_MODE" --icon "pause.circle" --color "#f9e2af" >/dev/null 2>&1 || true
  fi
else
  clear_status sdd_mode
fi

if [ -n "$SDD_SPEC" ]; then
  env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status sdd_spec "$SDD_SPEC" --icon "doc.text" --color "#89b4fa" >/dev/null 2>&1 || true
else
  clear_status sdd_spec
fi

if [ -n "$SDD_TASKS" ]; then
  env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status sdd_tasks "$SDD_TASKS" --icon "checklist" --color "#94e2d5" >/dev/null 2>&1 || true
else
  clear_status sdd_tasks
fi
