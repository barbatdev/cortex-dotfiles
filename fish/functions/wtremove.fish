function wtremove
    set -l name "$argv[1]"
    if test -z "$name"
        printf 'Usage: wtremove <name>\n' >&2
        return 1
    end
    set -l root (_wt_git_root); or begin
        printf 'Not inside a Git repository.\n' >&2
        return 1
    end
    set -l worktree (_wt_path_for "$root" "$name")
    if not test -d "$worktree"
        printf 'Worktree not found: %s\nUse wtlist to see active worktrees.\n' "$worktree" >&2
        return 1
    end
    git worktree remove "$worktree"; and git worktree prune; or return 1
    printf 'Worktree removed: %s\n' "$worktree"
end
