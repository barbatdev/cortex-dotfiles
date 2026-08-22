function clone-personaldev
    if test (count $argv) -lt 1
        printf 'Usage: clone-personaldev <org/repo|url>\n' >&2
        return 1
    end
    set -l repo (_parse_github_repo "$argv[1]")
    git clone "git@github-personaldev:$repo.git"
end
