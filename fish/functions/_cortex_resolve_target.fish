function _cortex_resolve_target
    set -l target "$argv[1]"
    test -n "$target"; or set target .

    if not test -d "$target"
        printf 'Directorio no encontrado: %s\n' "$target" >&2
        return 1
    end

    cd "$target"; and pwd
end
