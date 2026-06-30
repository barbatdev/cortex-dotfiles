# ssh-helpers.zsh — Remote helpers with visible host/repo context.

_remote_zellij_command_for_path() {
    local remote_path="$1"
    local shell_path

    if [[ "$remote_path" == "$HOME/"* ]]; then
        shell_path="~/${remote_path#$HOME/}"
    else
        shell_path="${(q)remote_path}"
    fi

    printf 'cd %s && root=$(git rev-parse --show-toplevel 2>/dev/null || pwd) && repo=$(basename "$root" | tr . -) && parent=$(basename "$(dirname "$root")" | tr . -) && session="$parent-$repo" && zellij attach --create "$session"' "$shell_path"
}

# Entrar a una workstation remota por Mosh. Si pasás path, attach/crea Zellij remoto por repo.
moshx() {
    local target="${1:?Uso: moshx <host> [remote-path]}"
    shift

    if ! command -v mosh >/dev/null 2>&1; then
        echo "❌ mosh no está instalado localmente; fallback: sshx $target ${*}"
        sshx "$target" "$@"
        return
    fi

    local remote_path="${1:-}"
    if [[ -z "$remote_path" ]]; then
        CORTEX_SSH_TARGET="$target" mosh "$target"
        return
    fi
    shift

    local remote_command
    remote_command="$(_remote_zellij_command_for_path "$remote_path")"
    CORTEX_SSH_TARGET="$target" mosh "$target" -- sh -lc "$remote_command" || {
        echo "⚠️  mosh falló; probando fallback SSH al mismo Zellij remoto"
        CORTEX_SSH_TARGET="$target" ssh -t "$target" sh -lc "$remote_command"
    }
}

# Diagnosticar dependencias remotas para moshx sin abrir sesión interactiva.
moshx-doctor() {
    local target="${1:?Uso: moshx-doctor <host>}"

    echo "Local:"
    command -v mosh >/dev/null 2>&1 && echo "  ✓ mosh: $(command -v mosh)" || echo "  ✗ mosh local no encontrado"

    echo "Remote $target:"
    ssh "$target" 'for cmd in mosh-server zellij git sh; do if command -v "$cmd" >/dev/null 2>&1; then printf "  ✓ %s: %s\n" "$cmd" "$(command -v "$cmd")"; else printf "  ✗ %s no encontrado\n" "$cmd"; fi; done'
}

# SSH directo, pero exportando CORTEX_SSH_TARGET para que el prompt muestre el host remoto.
sshc() {
    local target="${1:?Uso: sshc <host> [ssh args...]}"
    shift
    CORTEX_SSH_TARGET="$target" ssh "$target" "$@"
}

# Abrir SSH en una sesión Zellij local nombrada ssh-<host>. Fallback para hosts sin Mosh.
sshx() {
    local target="${1:?Uso: sshx <host> [ssh args...]}"
    shift

    if ! command -v zellij >/dev/null 2>&1; then
        sshc "$target" "$@"
        return
    fi

    local session
    session="ssh-${target//[^A-Za-z0-9_.-]/-}"
    local quoted_args=("${(@q)@}")
    local command_line="CORTEX_SSH_TARGET=${(q)target} ssh ${(q)target} ${quoted_args[*]}"

    if ! typeset -f _zellij_layout_for_command >/dev/null 2>&1 || ! typeset -f _zellij_session_exists >/dev/null 2>&1; then
        CORTEX_SSH_TARGET="$target" zellij --session "$session"
        return
    fi

    if [[ -n "$ZELLIJ" ]]; then
        if _zellij_session_exists "$session"; then
            zellij action switch-session "$session"
            return
        fi

        local layout_file
        layout_file="$(_zellij_layout_for_command "$PWD" "$command_line" "$session")"
        zellij action switch-session --layout "$layout_file" "$session"
    else
        if _zellij_session_exists "$session"; then
            zellij attach "$session"
            return
        fi

        local layout_file
        layout_file="$(_zellij_layout_for_command "$PWD" "$command_line" "$session")"
        zellij --session "$session" --layout "$layout_file"
    fi
}

# Mostrar contexto rápido del shell actual: host, cwd, git, zellij/tmux y ssh.
whereami() {
    printf 'host: %s\n' "$(hostname -s 2>/dev/null || hostname)"
    printf 'cwd:  %s\n' "$PWD"
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf 'repo: %s\n' "$(git rev-parse --show-toplevel)"
        printf 'branch: %s\n' "$(git branch --show-current 2>/dev/null || printf detached)"
    fi
    [[ -n "$ZELLIJ" ]] && printf 'zellij: %s\n' "${ZELLIJ_SESSION_NAME:-unknown}"
    [[ -n "$TMUX" ]] && printf 'tmux:   %s\n' "$(tmux display-message -p '#S:#W.#P' 2>/dev/null || printf unknown)"
    [[ -n "$SSH_CONNECTION" ]] && printf 'ssh:    %s\n' "${CORTEX_SSH_TARGET:-remote}"
}
