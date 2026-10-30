# Open the extra Herdr Desktop screens (one per monitor). Usage: herdr-screens [count]
# Screen 1 is the default home (~/.config/herdr-app); screens 2..count use
# ~/.config/herdr-app-N. Every screen shares the same herdr-core terminals.
# Theme, layout and mods are symlinked to the repo, so one edit reaches all
# screens; settings.json is copied once, because Herdr rewrites it (zoom,
# theme picker). Screens that already run are left alone.
function herdr-screens --description 'Open extra Herdr Desktop screens for multiple monitors'
    set -l count 4
    if test (count $argv) -gt 0
        set count $argv[1]
    end
    if not string match -qr '^[1-9][0-9]*$' -- $count
        printf 'herdr-screens: count must be a positive integer\n' >&2
        return 1
    end
    if not test -d /Applications/Herdr.app
        printf 'herdr-screens: /Applications/Herdr.app not found\n' >&2
        return 127
    end

    # The repo root, from this function's real location (fish/functions/).
    set -l repo (path resolve (status filename) | path dirname | path dirname | path dirname)
    set -l desktop "$repo/herdr/desktop"
    set -l shared themes/refactoria.json layouts/refactoria.json \
        mods/refactoria-spaces/main.js mods/refactoria-spaces/mod.json \
        mods/refactoria-agents/main.js mods/refactoria-agents/mod.json

    for n in (seq 2 $count)
        set -l home "$HOME/.config/herdr-app-$n"
        for f in $shared
            mkdir -p (path dirname "$home/$f")
            ln -sfn "$desktop/$f" "$home/$f"
        end
        if not test -e "$home/settings.json"
            cp "$desktop/settings.json" "$home/settings.json"
        end

        if env HERDR_APP_HOME="$home" herdr-app status >/dev/null 2>&1
            printf 'herdr-screens: screen %s already running\n' $n
        else
            open -n -a Herdr --env HERDR_APP_HOME="$home"
            printf 'herdr-screens: opened screen %s (%s)\n' $n "$home"
            # A new home starts on the main layout: switch it once it answers.
            for attempt in (seq 20)
                if env HERDR_APP_HOME="$home" herdr-app status >/dev/null 2>&1
                    env HERDR_APP_HOME="$home" herdr-app do layout.switch '{"name":"refactoria"}' >/dev/null 2>&1
                    break
                end
                sleep 0.5
            end
        end
    end
end
