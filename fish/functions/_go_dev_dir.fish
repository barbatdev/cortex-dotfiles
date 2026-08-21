function _go_dev_dir --argument-names target
    if test -d "$target"
        cd "$target"
        return 0
    end
    printf 'Directory not found: %s\n' "$target" >&2
    return 1
end
