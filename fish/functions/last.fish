# Usage: last [-c|--copy] [-o|--open] prints, copies, or opens the latest screenshot.
function last
    set -l copy false
    set -l open_file false

    for argument in $argv
        switch "$argument"
            case -c --copy
                set copy true
            case -o --open
                set open_file true
        end
    end

    set -l directory (_screenshots_dir)
    set -l files (_screenshot_files)
    set -l file "$files[1]"

    if test -z "$file"
        printf '⚠️  No se encontraron screenshots en: %s\n' "$directory"
        return 1
    end

    if test "$copy" = true
        printf '%s\n' "$file" | command pbcopy
        printf '✓ Path copiado: %s\n' (command basename "$file")
    else if test "$open_file" = true
        command open "$file"
        printf '✓ Abriendo: %s\n' (command basename "$file")
    else
        printf '%s\n' "$file"
    end
end
