# Usage: ccd [subpath]
function ccd
    set -l subpath "$argv[1]"
    set -l workspace "$WORKSPACE_DIR"
    test -n "$workspace"; or set workspace "$HOME/dev"
    set -l target "$workspace"
    test -n "$subpath"; and set target "$workspace/$subpath"

    if test -d "$target"
        cd "$target"
        printf 'Navegando a: %s\n' "$target"
    else
        printf 'Directorio no encontrado: %s\n' "$target" >&2
        return 1
    end
end
