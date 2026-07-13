# ssh-helpers.zsh — Remote helpers with visible host/repo context.

# SSH directo, pero exportando CORTEX_SSH_TARGET para que el prompt muestre el host remoto.
sshc() {
    local target="${1:?Uso: sshc <host> [ssh args...]}"
    shift
    [[ "$target" == -* ]] && { echo "Target SSH inválido: $target"; return 1; }
    CORTEX_SSH_TARGET="$target" ssh "$target" "$@"
}

# Abre un workspace remoto persistente en cmux usando aliases y opciones de ~/.ssh/config.
sshx() {
    local target="${1:?Uso: sshx <host> [cmux ssh args...]}"
    shift
    [[ "$target" == -* ]] && { echo "Target SSH inválido: $target"; return 1; }

    if ! command -v cmux >/dev/null 2>&1; then
        echo "cmux no está disponible; usá sshc para una conexión SSH directa"
        return 1
    fi

    CORTEX_SSH_TARGET="$target" cmux ssh "$target" "$@"
}

# Diagnostica el cliente cmux y la resolución SSH del host sin iniciar una sesión.
sshx-doctor() {
    local target="${1:?Uso: sshx-doctor <host>}"
    local failed=0
    [[ "$target" == -* ]] && { echo "Target SSH inválido: $target"; return 1; }

    command -v cmux >/dev/null 2>&1 || { echo "✗ cmux no encontrado"; failed=1; }
    command -v ssh >/dev/null 2>&1 || { echo "✗ ssh no encontrado"; failed=1; }
    if command -v ssh >/dev/null 2>&1 && ssh -G "$target" >/dev/null 2>&1; then
        echo "✓ SSH config resuelve: $target"
    else
        echo "✗ SSH config no resuelve: $target"
        failed=1
    fi

    return "$failed"
}
