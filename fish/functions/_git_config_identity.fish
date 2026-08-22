function _git_config_identity --argument-names name email alias label route_marker
    if test -z "$name"; or test -z "$email"
        printf 'Missing private %s identity: set name and email in 99-local.fish.\n' "$label" >&2
        return 1
    end

    git rev-parse --is-inside-work-tree >/dev/null 2>&1; or begin
        printf 'Not inside a Git repository.\n' >&2
        return 1
    end

    git config --local user.name "$name"; and git config --local user.email "$email"; or return 1
    set -l url (git remote get-url origin 2>/dev/null)
    if string match -q '*github.com*' -- "$url"; or string match -q "*$route_marker*" -- "$url"
        set -l new_url (string replace -r '^git@github[^:]*:' "git@$alias:" -- "$url")
        if test "$new_url" != "$url"
            git remote set-url origin "$new_url"; or return 1
            printf 'Remote updated: %s\n' "$new_url"
        end
    end

    printf 'Identity: %s (%s)\n' "$label" "$email"
end
