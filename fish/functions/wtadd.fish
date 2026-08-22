function wtadd
    set -l name "$argv[1]"
    if test -z "$name"
        printf 'Usage: wtadd <name> [branch]\n' >&2
        return 1
    end
    set -l branch "$name"
    if test (count $argv) -ge 2
        set branch "$argv[2]"
    end

    set -l root (_wt_git_root); or begin
        printf 'Not inside a Git repository.\n' >&2
        return 1
    end
    if _wt_is_pcsoft_repo
        printf 'PCSoft repository detected — worktrees are not allowed.\n' >&2
        return 1
    end

    set -l worktree (_wt_path_for "$root" "$name")
    if test -d "$worktree"
        printf 'Worktree already exists: %s\n' "$worktree" >&2
        return 1
    end
    mkdir -p (path dirname "$worktree"); or return 1
    if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"
        git worktree add "$worktree" "$branch"
    else
        git worktree add -b "$branch" "$worktree"
    end; or return 1

    printf 'Worktree created: %s\n' "$worktree"
    if test "$CORTEX_MULTIPLEXER" = cmux
        cc "$worktree"
    end
end
