# Usage: ccclip <file...> [-n|--line-numbers]
function ccclip
    if test (count $argv) -eq 0
        printf 'Uso: ccclip <archivo1> [archivo2 ...] [-n|--line-numbers]\n' >&2
        return 1
    end

    set -l with_numbers false
    set -l files
    for arg in $argv
        switch "$arg"
            case -n --line-numbers
                set with_numbers true
            case '*'
                set -a files "$arg"
        end
    end

    begin
        for file in $files
            if not test -f "$file"
                printf 'Archivo no encontrado: %s\n' "$file" >&2
                continue
            end

            set -l extension (path extension "$file" | string trim -c .)
            printf '```%s\n// File: %s\n' "$extension" "$file"
            set -l content
            if test "$with_numbers" = true
                set content (nl -ba "$file" | string collect)
            else
                set content (command cat "$file" | string collect)
            end
            printf '%s\n```\n\n' "$content"
        end
    end | pbcopy
    set -l clipboard_status $pipestatus[-1]
    if test "$clipboard_status" -ne 0
        return "$clipboard_status"
    end

    printf 'Contexto copiado al clipboard (%d archivos)\n' (count $files)
end
