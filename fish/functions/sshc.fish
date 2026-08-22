# Open a conventional SSH shell with Cortex target context. Usage: sshc <host> [ssh args...]
function sshc --description 'Open SSH with Cortex target context'
    if test (count $argv) -lt 1
        printf 'Uso: sshc <host> [ssh args...]\n' >&2
        return 2
    end
    set -l target $argv[1]
    if string match -q -- '-*' "$target"
        printf 'Target SSH inválido: %s\n' "$target" >&2
        return 1
    end
    if not command -q ssh
        printf 'sshc: ssh is not available\n' >&2
        return 127
    end
    set -e argv[1]
    env CORTEX_SSH_TARGET="$target" ssh "$target" $argv
end
