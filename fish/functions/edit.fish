function edit
    if test (count $argv) -lt 1
        printf 'Usage: edit <file>\n' >&2
        return 1
    end

    set -l target "$argv[1]"
    if is-pcsoft-forbidden "$target"
        printf 'PCSoft forbidden file: %s\nUse the WinDev/WebDev IDE.\n' "$target" >&2
        return 1
    end
    if is-pcsoft-editable "$target"
        printf "PCSoft editable file: %s\nOnly edit 'code : |1+' blocks with the IDE closed.\nContinue? [s/N] " "$target"
        read -l confirm
        string match -qr '^[sS]$' -- "$confirm"; or return 0
    end

    "$EDITOR" "$target"
end
