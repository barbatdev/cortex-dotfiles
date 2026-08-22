# Run Herdr directly. Usage: h [herdr args...]
function h --description 'Run Herdr directly'
    if not command -q herdr
        printf 'h: herdr is not available\n' >&2
        return 127
    end
    command herdr $argv
end
