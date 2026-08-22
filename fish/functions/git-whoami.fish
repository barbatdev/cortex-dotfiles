function git-whoami
    set -l name (git config user.name 2>/dev/null; or echo 'no configurado')
    set -l email (git config user.email 2>/dev/null; or echo 'no configurado')
    set -l remote (git remote get-url origin 2>/dev/null; or echo 'sin remote')
    printf '  nombre : %s\n  email  : %s\n  remote : %s\n' "$name" "$email" "$remote"
end
