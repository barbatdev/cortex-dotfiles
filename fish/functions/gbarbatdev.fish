# Open an isolated Ghostty instance with the Barbatdev profile. Usage: gbarbatdev [ghostty args...]
function gbarbatdev --description 'Open Ghostty with the Barbatdev profile'
    if not command -q open
        printf 'gbarbatdev: macOS open command is not available\n' >&2
        return 127
    end

    set -l ghostty /Applications/Ghostty.app/Contents/MacOS/ghostty
    if not test -x "$ghostty"
        printf 'gbarbatdev: Ghostty.app is not installed in /Applications\n' >&2
        return 1
    end

    set -l base "$HOME/.config/ghostty/config"
    set -l profile "$HOME/.config/ghostty/profiles/barbatdev.conf"
    if not test -r "$base"
        printf 'gbarbatdev: missing readable config: %s\n' "$base" >&2
        return 1
    end
    if not test -r "$profile"
        printf 'gbarbatdev: missing readable config: %s\n' "$profile" >&2
        return 1
    end

    set -l tmp_dir (command mktemp -d)
    set -l mktemp_status $status
    if test $mktemp_status -ne 0
        return $mktemp_status
    end
    if test -z "$tmp_dir"
        return 1
    end

    set -l config "$tmp_dir/config.ghostty"
    printf 'config-file = "%s"\nconfig-file = "%s"\n' "$base" "$profile" > "$config"
    set -l compose_status $status
    if test $compose_status -ne 0
        command rm -rf -- "$tmp_dir"
        return $compose_status
    end

    "$ghostty" +validate-config --config-file="$config"
    set -l validate_status $status
    if test $validate_status -ne 0
        printf 'gbarbatdev: composed Ghostty config is invalid\n' >&2
        command rm -rf -- "$tmp_dir"
        return $validate_status
    end

    open -W -na Ghostty --args --config-default-files=false --config-file="$config" --working-directory="$PWD" $argv
    set -l ghostty_status $status
    command rm -rf -- "$tmp_dir"
    return $ghostty_status
end
