# Usage: ssd opens the configured screenshots directory in Finder.
function ssd
    set -l directory (_screenshots_dir)

    if test -d "$directory"
        command open "$directory"
    else
        printf '⚠️  Directorio no encontrado: %s\n' "$directory"
    end
end
