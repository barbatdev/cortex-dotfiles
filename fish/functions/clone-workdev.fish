function clone-workdev
    if test (count $argv) -lt 1
        printf 'Usage: clone-workdev <org/repo|url>\n' >&2
        return 1
    end
    set -l repo (_parse_github_repo "$argv[1]")
    git clone "git@github-workdev:$repo.git"
end
