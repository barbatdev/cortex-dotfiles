# ssh-helpers.zsh — Remote helpers with visible host/repo context.

# SSH directo, pero exportando CORTEX_SSH_TARGET para que el prompt muestre el host remoto.
sshc() {
    local target="${1:?Uso: sshc <host> [ssh args...]}"
    shift
    [[ "$target" == -* ]] && { echo "Target SSH inválido: $target"; return 1; }
    CORTEX_SSH_TARGET="$target" ssh "$target" "$@"
}
