function _go_first_existing_dir
    for target in $argv
        if test -d "$target"
            cd "$target"
            return 0
        end
    end
    printf 'Directory not found: %s\n' "$argv[1]" >&2
    return 1
end
