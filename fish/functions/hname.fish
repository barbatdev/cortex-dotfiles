# Rename the current Herdr pane. Usage: hname [label]
function hname --description 'Rename the current Herdr pane'
    if not command -q herdr
        printf 'hname: herdr is not available\n' >&2
        return 127
    end
    if not command -q python3
        printf 'hname: python3 is not available\n' >&2
        return 127
    end
    set -l label $argv[1]
    if test -z "$label"
        set label (basename "$PWD" | string replace -a . -)
        set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
        if test -n "$git_root"
            set -l repo_name (basename "$git_root" | string replace -a . -)
            set -l parent_name (dirname "$git_root" | xargs basename | string replace -a . -)
            set -l branch (git -C "$git_root" branch --show-current 2>/dev/null)
            set label "$parent_name"-"$repo_name"
            test -n "$branch"; and set label "$label"-(string replace -ra '[^A-Za-z0-9_.-]' - "$branch")
        end
    end
    set -l pane_id (herdr pane current --current 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])' 2>/dev/null)
    if test -z "$pane_id"
        printf 'No pude detectar el pane actual de Herdr\n' >&2
        return 1
    end
    herdr pane rename "$pane_id" "$label" >/dev/null; or return
    printf 'pane: %s\n' "$label"
end
