function wtlist
    _wt_git_root >/dev/null; or begin
        printf 'Not inside a Git repository.\n' >&2
        return 1
    end
    printf '\n'
    git worktree list
    printf '\n'
end
