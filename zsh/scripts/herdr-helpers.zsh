# herdr-helpers.zsh — Remote-first Herdr helpers.

_herdr_context_label() {
    local host
    host="${HOST%%.*}"
    host="${host:-$(hostname -s 2>/dev/null || hostname)}"

    if [[ -n "$SSH_CONNECTION" || -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]; then
        printf 'ssh-%s' "$host"
    else
        printf 'local-%s' "$host"
    fi
}

_herdr_workspace_name_for_path() {
    local target="${1:-$PWD}"
    local git_root repo_name parent_name branch
    git_root=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || true)

    if [[ -n "$git_root" ]]; then
        repo_name=$(basename "$git_root" | tr '.' '-')
        parent_name=$(basename "$(dirname "$git_root")" | tr '.' '-')
        branch=$(git -C "$git_root" branch --show-current 2>/dev/null || true)
        if [[ -n "$branch" ]]; then
            printf '%s-%s-%s' "$parent_name" "$repo_name" "${branch//[^A-Za-z0-9_.-]/-}"
        else
            printf '%s-%s' "$parent_name" "$repo_name"
        fi
    else
        basename "$target" | tr '.' '-'
    fi
}

_herdr_session_name_for_path() {
    printf '%s-%s' "$(_herdr_context_label)" "$(_herdr_workspace_name_for_path "${1:-$PWD}")"
}

_herdr_session_name_with_suffix() {
    local session_path="${1:-$PWD}"
    local suffix="$2"

    if [[ -n "$suffix" ]]; then
        printf '%s-%s' "$(_herdr_session_name_for_path "$session_path")" "${suffix//[^A-Za-z0-9_.-]/-}"
    else
        _herdr_session_name_for_path "$session_path"
    fi
}

_herdr_open_session_for_path() {
    local target="${1:-$PWD}"
    local suffix="${2:-}"
    local resolved session workspace_label

    resolved=$(cd -q "$target" >/dev/null 2>&1 && pwd) || {
        echo "Directorio no encontrado: $target"
        return 1
    }

    if [[ "${HERDR_ENV:-}" == "1" ]]; then
        workspace_label="$(_herdr_session_name_with_suffix "$resolved" "$suffix")"
        workspace_label="${workspace_label#$(_herdr_context_label)-}"
        _herdr_focus_or_create_workspace "$workspace_label" "$resolved"
        return
    fi

    session="$(_herdr_session_name_with_suffix "$resolved" "$suffix")"
    CORTEX_MULTIPLEXER=herdr herdr --session "$session"
}

_herdr_workspace_id_by_label() {
    local label="$1"
    herdr workspace list 2>/dev/null | python3 -c '
import json
import sys

label = sys.argv[1]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

for workspace in data.get("result", {}).get("workspaces", []):
    if workspace.get("label") == label:
        print(workspace.get("workspace_id", ""))
        break
' "$label" 2>/dev/null
}

_herdr_focus_or_create_workspace() {
    local label="$1"
    local cwd="$2"
    local workspace_id

    workspace_id="$(_herdr_workspace_id_by_label "$label")"
    if [[ -n "$workspace_id" ]]; then
        herdr workspace focus "$workspace_id" >/dev/null && printf 'workspace: %s\n' "$label"
    else
        herdr workspace create --cwd "$cwd" --label "$label" --focus >/dev/null && printf 'workspace: %s\n' "$label"
    fi
}

_herdr_current_pane_id() {
    command -v herdr >/dev/null 2>&1 || return 1
    herdr pane current --current 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])' 2>/dev/null
}

# Entrar/crear una sesión Herdr nombrada por host + repo + branch del path actual.
hhere() {
    _herdr_open_session_for_path "${1:-$PWD}"
}

# Alias semántico de hhere: volver a la sesión principal del repo/branch actual.
hmain() {
    hhere "${1:-$PWD}"
}

# Entrar/crear una sesión Herdr con rol humano. Uso: hrole <rol> [path]
hrole() {
    local role="${1:?Uso: hrole <rol> [path]}"
    local target="${2:-$PWD}"
    _herdr_open_session_for_path "$target" "$role"
}

# Entrar/crear una sesión Herdr independiente con timestamp corto.
hnew() {
    local target="${1:-$PWD}"
    _herdr_open_session_for_path "$target" "new-$(date +%H%M%S)-$RANDOM"
}

# Entrar/crear la sesión Herdr de trabajo principal/intenso para este repo/branch.
hfocus() {
    _herdr_open_session_for_path "${1:-$PWD}" "focus"
}

# Entrar/crear una sesión Herdr lateral para este repo/branch.
hside() {
    _herdr_open_session_for_path "${1:-$PWD}" "side"
}

# Entrar/crear una sesión Herdr temporal para pruebas o tareas descartables.
hscratch() {
    _herdr_open_session_for_path "${1:-$PWD}" "scratch"
}

# Attach remoto con Herdr. Uso: hremote <ssh-target> [session]
hremote() {
    local target="${1:?Uso: hremote <ssh-target> [session]}"
    local session="${2:-main}"
    CORTEX_MULTIPLEXER=herdr CORTEX_SSH_TARGET="$target" herdr --remote "$target" --session "$session"
}

# Renombrar el pane actual de Herdr con un label humano o uno derivado de repo/branch.
hname() {
    local label="${1:-$(_herdr_workspace_name_for_path "$PWD")}" 
    local pane_id
    pane_id="$(_herdr_current_pane_id)" || {
        echo "No pude detectar el pane actual de Herdr"
        return 1
    }
    herdr pane rename "$pane_id" "$label" >/dev/null && printf 'pane: %s\n' "$label"
}

# Mostrar contexto completo del shell/pane actual.
herdr-orient() {
    printf 'host:   %s\n' "$(hostname -s 2>/dev/null || hostname)"
    printf 'cwd:    %s\n' "$PWD"
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf 'repo:   %s\n' "$(git rev-parse --show-toplevel)"
        printf 'branch: %s\n' "$(git branch --show-current 2>/dev/null || printf detached)"
    fi
    [[ -n "$SSH_CONNECTION" ]] && printf 'ssh:    %s\n' "${CORTEX_SSH_TARGET:-remote}"

    local pane_id
    pane_id="$(_herdr_current_pane_id)" && printf 'herdr:  %s\n' "$pane_id"
}

# Mantener el comando muscular, pero con contexto Herdr incluido cuando existe.
whereami() {
    herdr-orient
}

alias h='herdr'
alias hs='herdr status'
alias hl='herdr workspace list'
