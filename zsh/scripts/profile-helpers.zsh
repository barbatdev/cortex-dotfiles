# profile-helpers.zsh — Launch Herdr and Ghostty with a visual profile, and
# open the extra Herdr Desktop screens.

#region Herdr profiles
# Run Herdr in a throwaway session whose config is config-base.toml plus one profile.
_herdr_with_profile() {
    local name="$1" profile_name="$2"
    shift 2
    if [[ -n "${HERDR_ENV:-}" ]]; then
        printf '%s: launch this preview from an external shell or window, not from within Herdr\n' "$name" >&2
        return 1
    fi
    if ! command -v herdr >/dev/null 2>&1; then
        printf '%s: herdr is not available\n' "$name" >&2
        return 127
    fi

    local base="$HOME/.config/herdr/config-base.toml"
    local profile="$HOME/.config/herdr/profiles/$profile_name.toml"
    local f
    for f in "$base" "$profile"; do
        if [[ ! -r "$f" ]]; then
            printf '%s: missing readable config: %s\n' "$name" "$f" >&2
            return 1
        fi
    done

    local tmp_dir
    tmp_dir="$(command mktemp -d)" || return
    [[ -n "$tmp_dir" ]] || return 1

    if ! command cat -- "$base" "$profile" > "$tmp_dir/config.toml"; then
        command rm -rf -- "$tmp_dir"
        return 1
    fi

    env HERDR_CONFIG_PATH="$tmp_dir/config.toml" HERDR_SOCKET_PATH="$tmp_dir/herdr.sock" \
        HERDR_CLIENT_SOCKET_PATH="$tmp_dir/herdr-client.sock" herdr --no-session "$@"
    local herdr_status=$?
    command rm -rf -- "$tmp_dir"
    return $herdr_status
}

# Run Herdr with the Barbatdev profile. Usage: hbarbatdev [herdr args...]
hbarbatdev() { _herdr_with_profile hbarbatdev barbatdev "$@"; }

# Run Herdr with the RefactorIA profile. Usage: hrefactoria [herdr args...]
hrefactoria() { _herdr_with_profile hrefactoria refactoria "$@"; }
#endregion

#region Ghostty profiles
# Open an isolated Ghostty instance whose config is the base config plus one profile (macOS).
_ghostty_with_profile() {
    local name="$1" profile_name="$2"
    shift 2
    if ! command -v open >/dev/null 2>&1; then
        printf '%s: macOS open command is not available\n' "$name" >&2
        return 127
    fi

    local ghostty=/Applications/Ghostty.app/Contents/MacOS/ghostty
    if [[ ! -x "$ghostty" ]]; then
        printf '%s: Ghostty.app is not installed in /Applications\n' "$name" >&2
        return 1
    fi

    local base="$HOME/.config/ghostty/config"
    local profile="$HOME/.config/ghostty/profiles/$profile_name.conf"
    local f
    for f in "$base" "$profile"; do
        if [[ ! -r "$f" ]]; then
            printf '%s: missing readable config: %s\n' "$name" "$f" >&2
            return 1
        fi
    done

    local tmp_dir
    tmp_dir="$(command mktemp -d)" || return
    [[ -n "$tmp_dir" ]] || return 1

    local config="$tmp_dir/config.ghostty"
    if ! printf 'config-file = "%s"\nconfig-file = "%s"\n' "$base" "$profile" > "$config"; then
        command rm -rf -- "$tmp_dir"
        return 1
    fi

    if ! "$ghostty" +validate-config --config-file="$config"; then
        printf '%s: composed Ghostty config is invalid\n' "$name" >&2
        command rm -rf -- "$tmp_dir"
        return 1
    fi

    open -W -na Ghostty --args --config-default-files=false --config-file="$config" --working-directory="$PWD" "$@"
    local ghostty_status=$?
    command rm -rf -- "$tmp_dir"
    return $ghostty_status
}

# Open Ghostty with the Barbatdev profile. Usage: gbarbatdev [ghostty args...]
gbarbatdev() { _ghostty_with_profile gbarbatdev barbatdev "$@"; }

# Open Ghostty with the RefactorIA profile. Usage: grefactoria [ghostty args...]
grefactoria() { _ghostty_with_profile grefactoria refactoria "$@"; }
#endregion

#region Herdr Desktop screens
# Open the extra Herdr Desktop screens (one per monitor). Usage: herdr-screens [count]
# Screen 1 is the default home (~/.config/herdr-app); screens 2..count use
# ~/.config/herdr-app-N. Every screen shares the same herdr-core terminals.
# Theme, layout and mods are symlinked to the repo, so one edit reaches all
# screens; settings.json is copied once, because Herdr rewrites it (zoom,
# theme picker). Screens that already run are left alone.
herdr-screens() {
    local count="${1:-4}"
    if [[ ! "$count" =~ '^[1-9][0-9]*$' ]]; then
        printf 'herdr-screens: count must be a positive integer\n' >&2
        return 1
    fi
    if [[ ! -d /Applications/Herdr.app ]]; then
        printf 'herdr-screens: /Applications/Herdr.app not found\n' >&2
        return 127
    fi

    local desktop="$_DOTFILES_DIR/herdr/desktop"
    local -a shared=(themes/refactoria.json layouts/refactoria.json
        mods/refactoria-spaces/main.js mods/refactoria-spaces/mod.json
        mods/refactoria-agents/main.js mods/refactoria-agents/mod.json
        mods/refactoria-prs/main.js mods/refactoria-prs/mod.json)

    local n home f attempt
    for n in $(seq 2 "$count"); do
        home="$HOME/.config/herdr-app-$n"
        for f in "${shared[@]}"; do
            mkdir -p "$(dirname "$home/$f")"
            ln -sfn "$desktop/$f" "$home/$f"
        done
        [[ -e "$home/settings.json" ]] || cp "$desktop/settings.json" "$home/settings.json"

        if env HERDR_APP_HOME="$home" herdr-app status >/dev/null 2>&1; then
            printf 'herdr-screens: screen %s already running\n' "$n"
        else
            open -n -a Herdr --env HERDR_APP_HOME="$home"
            printf 'herdr-screens: opened screen %s (%s)\n' "$n" "$home"
            # A new home starts on the main layout: switch it once it answers.
            for attempt in $(seq 20); do
                if env HERDR_APP_HOME="$home" herdr-app status >/dev/null 2>&1; then
                    env HERDR_APP_HOME="$home" herdr-app do layout.switch '{"name":"refactoria"}' >/dev/null 2>&1
                    break
                fi
                sleep 0.5
            done
        fi
    done
}
#endregion
