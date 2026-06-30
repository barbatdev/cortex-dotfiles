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

_herdr_current_pane_id() {
    command -v herdr >/dev/null 2>&1 || return 1
    herdr pane current --current 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])' 2>/dev/null
}

# Entrar/crear una sesión Herdr nombrada por host + repo + branch del path actual.
hhere() {
    local target="${1:-$PWD}"
    local resolved session
    resolved=$(cd -q "$target" >/dev/null 2>&1 && pwd) || {
        echo "Directorio no encontrado: $target"
        return 1
    }
    session="$(_herdr_session_name_for_path "$resolved")"
    CORTEX_MULTIPLEXER=herdr herdr --session "$session"
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
