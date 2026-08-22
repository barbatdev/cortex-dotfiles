function _parse_github_repo --argument-names input
    set input (string replace -r '\.git$' '' -- "$input")
    set input (string replace -r '^https://github\.com/' '' -- "$input")
    string replace -r '^git@github[^:]*:' '' -- "$input"
end
