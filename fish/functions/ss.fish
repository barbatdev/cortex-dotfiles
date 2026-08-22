# Usage: ss [count] lists the most recent screenshots.
function ss
    set -l count "$argv[1]"
    test -n "$count"; or set count 10
    set -l directory (_screenshots_dir)

    if not test -d "$directory"
        printf '⚠️  Directorio no encontrado: %s\n' "$directory"
        printf '   Configurá SCREENSHOTS_DIR en local/env.zsh\n'
        return 1
    end

    printf '\n📸 Últimos %s screenshots en: %s\n\n' "$count" "$directory"

    set -l index 1
    for file in (_screenshot_files)
        set -l name (command basename "$file")
        set -l size (command du -sh "$file" 2>/dev/null | command cut -f1)
        set -l ago (_time_ago "$file")
        printf '  [%d] \033[1;37m%s\033[0m \033[90m(%s) — %s\033[0m\n' "$index" "$name" "$size" "$ago"

        set index (math "$index + 1")
        test "$index" -le "$count"; or break
    end

    printf '\n  Usá \033[1;33mlast\033[0m para obtener el path del último screenshot\n\n'
end
