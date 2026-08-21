# Print the current host, repository, SSH, and Herdr context. Usage: herdr-orient
function herdr-orient --description 'Print the current Herdr context'
    printf 'host:   %s\n' (hostname -s 2>/dev/null; or hostname)
    printf 'cwd:    %s\n' "$PWD"
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        printf 'repo:   %s\n' (git rev-parse --show-toplevel)
        set -l branch (git branch --show-current 2>/dev/null)
        test -n "$branch"; or set branch detached
        printf 'branch: %s\n' "$branch"
    end
    if test -n "$SSH_CONNECTION"
        set -l ssh_target $CORTEX_SSH_TARGET
        test -n "$ssh_target"; or set ssh_target remote
        printf 'ssh:    %s\n' "$ssh_target"
    end
    if command -q herdr; and command -q python3
        set -l pane_id (herdr pane current --current 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])' 2>/dev/null)
        test -n "$pane_id"; and printf 'herdr:  %s\n' "$pane_id"
    end
end
