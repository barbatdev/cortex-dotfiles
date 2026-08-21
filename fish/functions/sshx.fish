# Open a persistent cmux SSH workspace. Usage: sshx <host> [cmux ssh args...]
function sshx --description 'Open persistent cmux SSH workspace'
    if test (count $argv) -lt 1
        printf 'Uso: sshx <host> [cmux ssh args...]\n' >&2
        return 2
    end
    set -l target $argv[1]
    if string match -q -- '-*' "$target"
        printf 'Target SSH inválido: %s\n' "$target" >&2
        return 1
    end
    if not command -q cmux
        printf 'cmux no está disponible; usá sshc para una conexión SSH directa\n' >&2
        return 1
    end
    if not command -q ssh
        printf 'sshx: ssh is not available\n' >&2
        return 127
    end
    set -e argv[1]
    env CORTEX_SSH_TARGET="$target" cmux ssh "$target" $argv
end
