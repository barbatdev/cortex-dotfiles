# Enter the main Herdr session for a path. Usage: hhere [path]
function hhere --description 'Enter the main Herdr session for a path'
    if not command -q herdr
        printf 'hhere: herdr is not available\n' >&2
        return 127
    end
    set -l target $PWD
    test (count $argv) -ge 1; and set target $argv[1]
    set -l resolved (cd -- "$target" >/dev/null 2>&1; and pwd -P)
    if test -z "$resolved"
        printf 'Directorio no encontrado: %s\n' "$target" >&2
        return 1
    end
    set -l host $HOST
    if test -z "$host"
        set host (hostname -s 2>/dev/null; or hostname)
    end
    set host (string split -m 1 . -- "$host")[1]
    set -l context local
    test -n "$SSH_CONNECTION$SSH_CLIENT$SSH_TTY"; and set context ssh
    set -l workspace_label (basename "$resolved" | string replace -a . -)
    set -l git_root (git -C "$resolved" rev-parse --show-toplevel 2>/dev/null)
    if test -n "$git_root"
        set -l repo_name (basename "$git_root" | string replace -a . -)
        set -l parent_name (dirname "$git_root" | xargs basename | string replace -a . -)
        set -l branch (git -C "$git_root" branch --show-current 2>/dev/null)
        set workspace_label "$parent_name"-"$repo_name"
        test -n "$branch"; and set workspace_label "$workspace_label"-(string replace -ra '[^A-Za-z0-9_.-]' - "$branch")
    end
    set -l session "$context"-"$host"-"$workspace_label"
    if test "$HERDR_ENV" = 1
        if not command -q python3
            printf 'hhere: python3 is not available\n' >&2
            return 127
        end
        set -l workspace_id (herdr workspace list 2>/dev/null | python3 -c '
import json
import sys
label = sys.argv[1]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for workspace in data.get("result", {}).get("workspaces", []):
    if workspace.get("label") == label:
        print(workspace.get("workspace_id", ""))
        break
' "$workspace_label" 2>/dev/null)
        if test -n "$workspace_id"
            herdr workspace focus "$workspace_id" >/dev/null; or return
        else
            herdr workspace create --cwd "$resolved" --label "$workspace_label" --focus >/dev/null; or return
        end
        printf 'workspace: %s\n' "$workspace_label"
        return 0
    end
    env CORTEX_MULTIPLEXER=herdr herdr --session "$session"
end
