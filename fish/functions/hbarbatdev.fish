# Run Herdr with the Barbatdev profile. Usage: hbarbatdev [herdr args...]
function hbarbatdev --description 'Run Herdr with the Barbatdev profile'
    if set -q HERDR_ENV
        printf 'hbarbatdev: launch this preview from an external Fish shell or window, not from within Herdr\n' >&2
        return 1
    end

    if not command -q herdr
        printf 'hbarbatdev: herdr is not available\n' >&2
        return 127
    end

    set -l base "$HOME/.config/herdr/config-base.toml"
    set -l profile "$HOME/.config/herdr/profiles/barbatdev.toml"
    if not test -r "$base"
        printf 'hbarbatdev: missing readable config: %s\n' "$base" >&2
        return 1
    end
    if not test -r "$profile"
        printf 'hbarbatdev: missing readable config: %s\n' "$profile" >&2
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

    set -l config "$tmp_dir/config.toml"
    set -l server_socket "$tmp_dir/herdr.sock"
    set -l client_socket "$tmp_dir/herdr-client.sock"

    command cat -- "$base" "$profile" > "$config"
    set -l cat_status $status
    if test $cat_status -ne 0
        command rm -rf -- "$tmp_dir"
        return $cat_status
    end

    env HERDR_CONFIG_PATH="$config" HERDR_SOCKET_PATH="$server_socket" HERDR_CLIENT_SOCKET_PATH="$client_socket" herdr --no-session $argv
    set -l herdr_status $status
    command rm -rf -- "$tmp_dir"
    return $herdr_status
end
