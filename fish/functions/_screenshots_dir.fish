function _screenshots_dir
    if set -q SCREENSHOTS_DIR; and test -n "$SCREENSHOTS_DIR"; and test -d "$SCREENSHOTS_DIR"
        printf '%s\n' "$SCREENSHOTS_DIR"
        return
    end

    set -l default "$HOME/Screenshots"
    if test -d "$default"
        printf '%s\n' "$default"
    else
        printf '%s\n' "$HOME/Desktop"
    end
end
