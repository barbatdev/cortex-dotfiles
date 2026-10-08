function _go_first_existing_dir
    for target in $argv
        if test -d "$target"
            cd "$target"
            return 0
        end
    end
    # No candidate exists: walk up to the nearest existing ancestor of the
    # first target so navigation commands degrade gracefully on hosts that
    # do not have this part of the workspace layout.
    set -l probe "$argv[1]"
    while test -n "$probe"; and not test -d "$probe"
        set probe (dirname "$probe")
    end
    if test -n "$probe"; and test -d "$probe"
        printf 'Directory not found: %s — nearest existing: %s\n' "$argv[1]" "$probe" >&2
        cd "$probe"
        return 0
    end
    printf 'Directory not found: %s\n' "$argv[1]" >&2
    return 1
end
