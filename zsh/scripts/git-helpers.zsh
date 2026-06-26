#region Git Helpers
# Helpers para manejo de múltiples identidades GitHub

# Normaliza cualquier formato de URL de GitHub a "org/repo"
_parse_github_repo() {
    local input="$1"
    # Eliminar .git final
    input="${input%.git}"
    # https://github.com/org/repo → org/repo
    input="${input#https://github.com/}"
    # git@github.com:org/repo → org/repo
    input="${input#git@github.com:}"
    # git@github-alias:org/repo → org/repo
    input="${input#git@github*:}"
    echo "$input"
}

# Clonar repo de la cuenta workdev (tu cuenta de trabajo/empresa)
# Uso: clone-workdev <org/repo>
#   Acepta: org/repo · org/repo.git · https://github.com/org/repo · git@github.com:org/repo.git
clone-workdev() {
    local raw="${1:?Uso: clone-workdev <org/repo|url>}"
    local repo
    repo=$(_parse_github_repo "$raw")
    git clone "git@github-workdev:$repo.git"
}

# Clonar repo de la cuenta personaldev (tu cuenta personal)
# Uso: clone-personaldev <org/repo>
#   Acepta: org/repo · org/repo.git · https://github.com/org/repo · git@github.com:org/repo.git
clone-personaldev() {
    local raw="${1:?Uso: clone-personaldev <org/repo|url>}"
    local repo
    repo=$(_parse_github_repo "$raw")
    git clone "git@github-personaldev:$repo.git"
}

# Configurar identidad workdev (trabajo/empresa) en el repo actual
git-workdev() {
    git config user.name "YOUR_NAME"
    git config user.email "you@yourorg.com"

    # Actualizar remote si apunta a github.com o alias viejo
    local url
    url=$(git remote get-url origin 2>/dev/null)
    if [[ "$url" == *"github.com"* || "$url" == *"github-work"* ]]; then
        local new_url
        new_url=$(echo "$url" | sed 's|git@github[^:]*:|git@github-workdev:|')
        git remote set-url origin "$new_url"
        echo "✓ Remote actualizado: $new_url"
    fi

    echo "✓ Identidad: workdev (you@yourorg.com)"
}

# Configurar identidad personaldev (cuenta personal) en el repo actual
git-personaldev() {
    git config user.name "YOUR_NAME"
    git config user.email "you@personal.dev"

    # Actualizar remote si apunta a github.com o alias viejo
    local url
    url=$(git remote get-url origin 2>/dev/null)
    if [[ "$url" == *"github.com"* || "$url" == *"github-personal"* ]]; then
        local new_url
        new_url=$(echo "$url" | sed 's|git@github[^:]*:|git@github-personaldev:|')
        git remote set-url origin "$new_url"
        echo "✓ Remote actualizado: $new_url"
    fi

    echo "✓ Identidad: personaldev (you@personal.dev)"
}

# Ver identidad configurada en el repo actual
git-whoami() {
    local name email remote
    name=$(git config user.name 2>/dev/null || echo "no configurado")
    email=$(git config user.email 2>/dev/null || echo "no configurado")
    remote=$(git remote get-url origin 2>/dev/null || echo "sin remote")
    echo "  nombre : $name"
    echo "  email  : $email"
    echo "  remote : $remote"
}

#endregion
