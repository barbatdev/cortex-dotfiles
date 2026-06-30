#!/bin/bash

# InnIT Tech Slate colors (truecolor ANSI)
PRIMARY='\033[38;2;0;84;255m'       # InnIT blue (#0054ff)
ACCENT='\033[38;2;210;153;34m'      # warning (#D29922)
SECONDARY='\033[38;2;88;166;255m'   # info blue (#58A6FF)
MUTED='\033[38;2;139;148;158m'      # secondary text (#8B949E)
SUCCESS='\033[38;2;63;185;80m'      # engineering green (#3FB950)
ERROR='\033[38;2;248;81;73m'        # error (#F85149)
PURPLE='\033[38;2;139;92;246m'      # syntax purple (#8B5CF6)
BOLD='\033[1m'
STRIKE='\033[9m'
NC='\033[0m'

# Cache para MCP (evita llamar cada 300ms)
MCP_CACHE_TTL=120  # 2 minutos

# Leer JSON desde stdin
input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  printf 'Claude Code'
  exit 0
fi

# Parsear campos básicos
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // "~"')
MCP_CACHE_KEY=$(printf '%s' "$DIR" | tr '/ ' '__')
MCP_CACHE_FILE="/tmp/claude_mcp_cache_${MCP_CACHE_KEY}"

# --- Integración cmux sidebar ---
# CMUX_WORKSPACE_ID no se hereda desde Claude Code — leerlo desde el archivo
# que escribió cmux-claude-hook.sh en session-start (keyed por directorio)
if [ -z "$CMUX_WORKSPACE_ID" ]; then
  _SAFE_DIR=$(echo "$DIR" | tr '/' '_')
  _WS_FILE="/tmp/cmux_ws_${_SAFE_DIR}"
  [ -f "$_WS_FILE" ] && CMUX_WORKSPACE_ID=$(cat "$_WS_FILE" 2>/dev/null)
fi
# Exportar para que cmux lo use nativamente en subprocesos (& background)
export CMUX_WORKSPACE_ID

# Detectar binary cmux (solo si tenemos workspace ID)
CMUX_BIN=""
if [ -n "$CMUX_WORKSPACE_ID" ]; then
  if command -v cmux > /dev/null 2>&1; then
    CMUX_BIN="cmux"
  elif [ -x "/Applications/cmux.app/Contents/Resources/bin/cmux" ]; then
    CMUX_BIN="/Applications/cmux.app/Contents/Resources/bin/cmux"
  fi
fi
ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Ventana de contexto — usa used_percentage del JSON (mismo cálculo que auto-compact)
CTX_PERCENT=$(echo "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
if [ -z "$CTX_PERCENT" ] || [ "$CTX_PERCENT" = "null" ]; then
  CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
  INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
  CACHE_CREATE=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
  CACHE_READ=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
  TOTAL_USED=$((INPUT_TOKENS + CACHE_CREATE + CACHE_READ))
  if [ "$CTX_SIZE" -gt 0 ] 2>/dev/null; then
    CTX_PERCENT=$((TOTAL_USED * 100 / CTX_SIZE))
  else
    CTX_PERCENT=0
  fi
else
  CTX_PERCENT=$(echo "$CTX_PERCENT" | awk '{printf "%d", $1 + 0.5}')
fi
[ "$CTX_PERCENT" -gt 100 ] && CTX_PERCENT=100
[ "$CTX_PERCENT" -lt 0 ] && CTX_PERCENT=0

# Obtener servidores MCP desde config
get_mcp_servers() {
  if [ -f "$MCP_CACHE_FILE" ]; then
    CACHE_AGE=$(($(date +%s) - $(stat -f %m "$MCP_CACHE_FILE" 2>/dev/null || echo 0)))
    if [ "$CACHE_AGE" -lt "$MCP_CACHE_TTL" ]; then
      cat "$MCP_CACHE_FILE"
      return
    fi
  fi

  local CURRENT_DIR
  CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir // ""')

  local SERVERS=""

  if [ -n "$CURRENT_DIR" ]; then
    SERVERS=$(jq -r ".projects[\"$CURRENT_DIR\"].mcpServers // {} | keys[]" "$HOME/.claude.json" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  fi

  if [ -z "$SERVERS" ]; then
    SERVERS=$(jq -r ".projects[\"$HOME\"].mcpServers // {} | keys[]" "$HOME/.claude.json" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  fi

  echo "$SERVERS|" > "$MCP_CACHE_FILE"
  echo "$SERVERS|"
}

MCP_DATA=$(get_mcp_servers)
MCP_CONNECTED=$(echo "$MCP_DATA" | cut -d'|' -f1)
MCP_DISCONNECTED=$(echo "$MCP_DATA" | cut -d'|' -f2)

label_brain() {
  case "$1" in
    work-brain) printf 'work' ;;
    life-brain) printf 'life' ;;
    second-brain) printf 'notes' ;;
    *) return 1 ;;
  esac
}

format_brains() {
  local result=""
  local extras=0

  if [ -n "$MCP_CONNECTED" ]; then
    IFS=',' read -ra SERVERS <<< "$MCP_CONNECTED"
    for srv in "${SERVERS[@]}"; do
      local label
      if label=$(label_brain "$srv"); then
        [ -n "$result" ] && result+=" "
        result+="${SUCCESS}${label}${NC}"
      else
        extras=$((extras + 1))
      fi
    done
  fi

  if [ -n "$MCP_DISCONNECTED" ]; then
    IFS=',' read -ra SERVERS <<< "$MCP_DISCONNECTED"
    for srv in "${SERVERS[@]}"; do
      local label
      if label=$(label_brain "$srv"); then
        [ -n "$result" ] && result+=" "
        result+="${ERROR}${STRIKE}${label}${NC}"
      fi
    done
  fi

  if [ "$extras" -gt 0 ]; then
    [ -n "$result" ] && result+=" "
    result+="${MUTED}mcp+${extras}${NC}"
  fi

  echo "$result"
}

format_mcp() {
  local result=""

  if [ -n "$MCP_CONNECTED" ]; then
    IFS=',' read -ra SERVERS <<< "$MCP_CONNECTED"
    for srv in "${SERVERS[@]}"; do
      [ -n "$result" ] && result+=" "
      result+="${SUCCESS}${srv}${NC}"
    done
  fi

  if [ -n "$MCP_DISCONNECTED" ]; then
    IFS=',' read -ra SERVERS <<< "$MCP_DISCONNECTED"
    for srv in "${SERVERS[@]}"; do
      [ -n "$result" ] && result+=" "
      result+="${ERROR}${STRIKE}${srv}${NC}"
    done
  fi

  if [ -z "$result" ]; then
    echo "${MUTED}no mcp${NC}"
  else
    echo "$result"
  fi
}

MCP_DISPLAY=$(format_mcp)
BRAINS_DISPLAY=$(format_brains)

realpath_portable() {
  local target="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$target"
  else
    python3 - <<'PY' "$target"
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
  fi
}

# Estado SDD desde artefactos .ai/
get_sdd_status() {
  local current_dir
  current_dir=$(echo "$input" | jq -r '.workspace.current_dir // ""')
  [ -z "$current_dir" ] && echo "|" && return

  local ai_dir="$current_dir/.ai"
  [ ! -d "$ai_dir" ] && echo "|" && return

  local script_path
  script_path=$(realpath_portable "${BASH_SOURCE[0]}")
  local repo_root="$(cd "$(dirname "$script_path")/../.." && pwd)"
  local resume_script="$repo_root/scripts/sdd-resume-context.sh"

  local mode=""
  local active_spec=""
  local tasks_summary=""
  local status=""

  if [ -x "$resume_script" ]; then
    local resume_json
    resume_json=$("$resume_script" get "$current_dir" 2>/dev/null || true)
    if [ -n "$resume_json" ]; then
      status=$(echo "$resume_json" | jq -r '.status // empty' 2>/dev/null)
      mode=$(echo "$resume_json" | jq -r '.execution_mode // empty' 2>/dev/null)

      case "$status" in
        ready)
          active_spec=$(echo "$resume_json" | jq -r '.feature // empty' 2>/dev/null)
          local tasks_file
          tasks_file=$(echo "$resume_json" | jq -r '.tasks_path // empty' 2>/dev/null)
          if [ -n "$tasks_file" ] && [ -f "$current_dir/$tasks_file" ]; then
            local done pending
            done=$(grep -c '^- \[x\]' "$current_dir/$tasks_file" 2>/dev/null || echo 0)
            pending=$(grep -c '^- \[ \]' "$current_dir/$tasks_file" 2>/dev/null || echo 0)
            tasks_summary="${done}/${pending}"
          fi
          ;;
        ambiguous_feature)
          active_spec="ambiguous"
          ;;
        incomplete_feature)
          active_spec="incomplete"
          ;;
      esac
    fi
  fi

  echo "${mode}|${active_spec}|${tasks_summary}"
}

SDD_DATA=$(get_sdd_status)
SDD_MODE=$(echo "$SDD_DATA" | cut -d'|' -f1)
SDD_SPEC=$(echo "$SDD_DATA" | cut -d'|' -f2)
SDD_TASKS=$(echo "$SDD_DATA" | cut -d'|' -f3)

# Nombre del directorio
DIR_NAME=$(basename "$DIR")

# Info de git
BRANCH=""
GIT_DIRTY=""
if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
  if [[ -n $(git -C "$DIR" status --porcelain 2>/dev/null) ]]; then
    GIT_DIRTY="*"
  fi
fi

# Icono del modelo
MODEL_ICON="🤖"
case "$MODEL" in
  *Opus*)   MODEL_ICON="🎭" ;;
  *Sonnet*) MODEL_ICON="📝" ;;
  *Haiku*)  MODEL_ICON="🍃" ;;
esac

# Barra de progreso del contexto
BAR_WIDTH=8
FILLED=$((CTX_PERCENT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))

if [ "$CTX_PERCENT" -ge 80 ]; then
  BAR_COLOR="$ERROR"
elif [ "$CTX_PERCENT" -ge 50 ]; then
  BAR_COLOR="$ACCENT"
else
  BAR_COLOR="$SUCCESS"
fi

BAR="${BAR_COLOR}["
for ((i=0; i<FILLED; i++)); do BAR+="="; done
for ((i=0; i<EMPTY; i++)); do BAR+="."; done
BAR+="]${NC}"

# Construir línea de estado
SEP="${MUTED}  ${NC}"

LINE="${BOLD}${PURPLE}${MODEL_ICON} ${MODEL}${NC}"
LINE+="${SEP}"
LINE+="${ACCENT} ${DIR_NAME}${NC}"

if [ -n "$BRANCH" ]; then
  LINE+="${SEP}"
  LINE+="${SECONDARY} ${BRANCH}${GIT_DIRTY}${NC}"
fi

LINE+="${SEP}"
LINE+="${SUCCESS}+${ADDED}${NC} ${ERROR}-${REMOVED}${NC}"

LINE+="${SEP}"
LINE+="${MUTED}ctx${NC} ${BAR} ${MUTED}${CTX_PERCENT}%${NC}"

if [ -n "$BRAINS_DISPLAY" ]; then
  LINE+="${SEP}"
  LINE+="${MUTED}brains:${NC} ${BRAINS_DISPLAY}"
elif [ -n "$MCP_CONNECTED" ]; then
  LINE+="${SEP}"
  LINE+="${MUTED}mcp:${NC} ${MCP_DISPLAY}"
fi

if [ -n "$SDD_MODE" ]; then
  LINE+="${SEP}"
  if [ "$SDD_MODE" = "auto" ]; then
    LINE+="${MUTED}sdd:${NC} ${SUCCESS}${SDD_MODE}${NC}"
  else
    LINE+="${MUTED}sdd:${NC} ${ACCENT}${SDD_MODE}${NC}"
  fi
fi

if [ -n "$SDD_SPEC" ]; then
  LINE+="${SEP}"
  LINE+="${MUTED}spec:${NC} ${SECONDARY}${SDD_SPEC}${NC}"
fi

if [ -n "$SDD_TASKS" ]; then
  LINE+="${SEP}"
  LINE+="${MUTED}tasks:${NC} ${SUCCESS}${SDD_TASKS}${NC}"
fi

# Actualizar sidebar cmux con progreso y modelo
if [ -n "$CMUX_BIN" ]; then
  clear_sidebar_status() {
    # env -u descarta el socket heredado del caller; cmux auto-descubre el socket vivo
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" clear-status "$1" --workspace "$CMUX_WORKSPACE_ID" > /dev/null 2>&1 || true
  }

  # Modelo abreviado — siempre actualizar (cache por modelo para no spamear)
  case "$MODEL" in
    *Opus*)   MODEL_SHORT="O4.6" ;;
    *Sonnet*) MODEL_SHORT="S4.6" ;;
    *Haiku*)  MODEL_SHORT="H4.5" ;;
    *)        MODEL_SHORT="Claude" ;;
  esac
  MODEL_CACHE="/tmp/cmux_model_${CMUX_WORKSPACE_ID}"
  PREV_MODEL=""
  [ -f "$MODEL_CACHE" ] && PREV_MODEL=$(cat "$MODEL_CACHE" 2>/dev/null)
  if [ "$MODEL_SHORT" != "$PREV_MODEL" ]; then
    echo "$MODEL_SHORT" > "$MODEL_CACHE"
    # env -u descarta el socket heredado del caller para evitar "Connection refused"
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status claude_model "$MODEL_SHORT" --icon "cpu" --color "#3FB950" > /dev/null 2>&1
  fi

  if [ -n "$SDD_MODE" ]; then
    if [ "$SDD_MODE" = "auto" ]; then
      env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status sdd_mode "$SDD_MODE" --icon "arrow.right.circle" --color "#3FB950" > /dev/null 2>&1
    else
      env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status sdd_mode "$SDD_MODE" --icon "pause.circle" --color "#D29922" > /dev/null 2>&1
    fi
  else
    clear_sidebar_status sdd_mode
  fi

  if [ -n "$SDD_SPEC" ]; then
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status sdd_spec "$SDD_SPEC" --icon "doc.text" --color "#0054ff" > /dev/null 2>&1
  else
    clear_sidebar_status sdd_spec
  fi

  if [ -n "$SDD_TASKS" ]; then
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status sdd_tasks "$SDD_TASKS" --icon "checklist" --color "#58A6FF" > /dev/null 2>&1
  else
    clear_sidebar_status sdd_tasks
  fi

  if [ -n "$BRAINS_DISPLAY" ]; then
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-status brains "$(printf '%s' "$BRAINS_DISPLAY" | sed -E 's/\x1b\[[0-9;]*m//g')" --icon "brain.head.profile" --color "#58A6FF" > /dev/null 2>&1
  else
    clear_sidebar_status brains
  fi

  # Progreso — throttle: solo actualizar si cambio ≥ 2 puntos
  PROGRESS_CACHE="/tmp/cmux_progress_${CMUX_WORKSPACE_ID}"
  PREV_CTX=0
  [ -f "$PROGRESS_CACHE" ] && PREV_CTX=$(cat "$PROGRESS_CACHE" 2>/dev/null || echo 0)
  DIFF=$(( CTX_PERCENT - PREV_CTX ))
  [ "$DIFF" -lt 0 ] && DIFF=$(( -DIFF ))
  if [ "$DIFF" -ge 2 ]; then
    echo "$CTX_PERCENT" > "$PROGRESS_CACHE"
    PROGRESS_VAL=$(awk "BEGIN {printf \"%.2f\", $CTX_PERCENT / 100}")
    # env -u descarta el socket heredado del caller para evitar "Connection refused"
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" set-progress "$PROGRESS_VAL" --label "ctx ${CTX_PERCENT}%" > /dev/null 2>&1
  fi
fi

echo -e "${LINE}\033[K"
