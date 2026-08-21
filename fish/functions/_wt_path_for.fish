function _wt_path_for --argument-names git_root name
    printf '%s/dev/worktrees/%s/%s\n' "$HOME" (path basename "$git_root") "$name"
end
