# ssh-helpers.zsh — Remote helpers with visible host/repo context.

_remote_herdr_command_for_path() {
    local remote_path="$1"
    local shell_path

    if [[ "$remote_path" == "$HOME/"* ]]; then
        shell_path="~/${remote_path#$HOME/}"
    else
        shell_path="${(q)remote_path}"
    fi

    printf 'cd %s && exec ${SHELL:-zsh}' "$shell_path"
}

# Entrar a una workstation remota por Mosh. Si pasás path, entra directo a ese directorio.
moshx() {
    local target="${1:?Uso: moshx <host> [remote-path]}"
    shift

    if ! command -v mosh >/dev/null 2>&1; then
        echo "mosh no está instalado localmente; fallback: sshx $target ${*}"
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
    remote_command="$(_remote_herdr_command_for_path "$remote_path")"
    CORTEX_SSH_TARGET="$target" mosh "$target" -- sh -lc "$remote_command" || {
        echo "mosh falló; probando fallback SSH al mismo directorio remoto"
        CORTEX_SSH_TARGET="$target" ssh -t "$target" sh -lc "$remote_command"
    }
}

# Diagnosticar dependencias remotas para moshx/herdr sin abrir sesión interactiva.
moshx-doctor() {
    local target="${1:?Uso: moshx-doctor <host>}"

    echo "Local:"
    command -v mosh >/dev/null 2>&1 && echo "  ✓ mosh: $(command -v mosh)" || echo "  ✗ mosh local no encontrado"
    command -v herdr >/dev/null 2>&1 && echo "  ✓ herdr: $(command -v herdr)" || echo "  ✗ herdr local no encontrado"

    echo "Remote $target:"
    ssh "$target" 'for cmd in mosh-server herdr git sh; do if command -v "$cmd" >/dev/null 2>&1; then printf "  ✓ %s: %s\n" "$cmd" "$(command -v "$cmd")"; else printf "  ✗ %s no encontrado\n" "$cmd"; fi; done'
}

# SSH directo, pero exportando CORTEX_SSH_TARGET para que el prompt muestre el host remoto.
sshc() {
    local target="${1:?Uso: sshc <host> [ssh args...]}"
    shift
    CORTEX_SSH_TARGET="$target" ssh "$target" "$@"
}

# SSH directo con contexto visible. Herdr se encarga de la persistencia fuera de SSH.
sshx() {
    sshc "$@"
}
