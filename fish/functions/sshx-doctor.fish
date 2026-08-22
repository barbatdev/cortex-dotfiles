# Check cmux and SSH host resolution without connecting. Usage: sshx-doctor <host>
function sshx-doctor --description 'Check cmux and SSH host resolution'
    if test (count $argv) -lt 1
        printf 'Uso: sshx-doctor <host>\n' >&2
        return 2
    end
    set -l target $argv[1]
    if string match -q -- '-*' "$target"
        printf 'Target SSH inválido: %s\n' "$target" >&2
        return 1
    end

    set -l failed 0
    if not command -q cmux
        printf '✗ cmux no encontrado\n'
        set failed 1
    end
    if not command -q ssh
        printf '✗ ssh no encontrado\n'
        set failed 1
    else if ssh -G "$target" >/dev/null 2>&1
        printf '✓ SSH config resuelve: %s\n' "$target"
    else
        printf '✗ SSH config no resuelve: %s\n' "$target"
        set failed 1
    end
    return $failed
end
