# Attach to a remote Herdr session. Usage: hremote <ssh-target> [session]
function hremote --description 'Attach to a remote Herdr session'
    if test (count $argv) -lt 1
        printf 'Usage: hremote <ssh-target> [session]\n' >&2
        return 2
    end

    if not command -q herdr
        printf 'hremote: herdr is not available\n' >&2
        return 127
    end

    set -l target $argv[1]
    set -l session main
    if test (count $argv) -ge 2
        set session $argv[2]
    end

    env CORTEX_MULTIPLEXER=herdr CORTEX_SSH_TARGET="$target" herdr --remote "$target" --session "$session"
end
