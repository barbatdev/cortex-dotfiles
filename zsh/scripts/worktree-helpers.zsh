#region Worktree Helpers
# Funciones para gestión de git worktrees con integración Herdr.
# Detecta repos PCSoft automáticamente y bloquea la creación de worktrees en ellos.

# Verifica si el repo actual contiene archivos PCSoft (Categoría B — prohibido worktree)
_wt_is_pcsoft_repo() {
    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1

    # Buscar cualquier extensión PCSoft en el árbol (solo nombre, no contenido)
    local pcsoft_exts="wdp|wwp|wpp|wpj|wwh|wpw|prw|wdd|fic|mmo|ndx|wdr|wdq|wdi|wdt|wdv|wdk|rep|sty|cpl|bkp|wdg|wdc|wde|wdw"
    git -C "$git_root" ls-files 2>/dev/null \
        | grep -qE "\.(${pcsoft_exts})$"
}

# Obtiene el directorio raíz del repo actual
_wt_git_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Directorio base para worktrees por repo.
_wt_base_dir() {
    printf '%s/dev/worktrees' "$HOME"
}

# Calcula el path de worktree usando ~/dev/worktrees/<repo>/<nombre>.
_wt_path_for() {
    local git_root="$1"
    local name="$2"
    local repo_name
    repo_name=$(basename "$git_root")
    printf '%s/%s/%s' "$(_wt_base_dir)" "$repo_name" "$name"
}

# Crea un worktree en ~/dev/worktrees/<repo>/ y abre el agente desde Herdr.
# Uso: wtadd <nombre> [branch]
#   <nombre>  — nombre del worktree (crea ~/dev/worktrees/<repo>/<nombre>)
#   [branch]  — branch existente o nueva (default: crea branch nueva con el mismo nombre)
wtadd() {
    local name="$1"
    local branch="${2:-$1}"

    if [[ -z "$name" ]]; then
        echo "Uso: wtadd <nombre> [branch]"
        echo "  Ejemplos:"
        echo "    wtadd hotfix-login          # crea branch hotfix-login"
        echo "    wtadd review-pr main        # usa branch main existente"
        return 1
    fi

    # Verificar que estamos en un repo git
    local git_root
    git_root=$(_wt_git_root) || { echo "❌ No estás dentro de un repo git"; return 1; }

    # Bloquear en repos PCSoft
    if _wt_is_pcsoft_repo; then
        echo "❌ Repo PCSoft detectado — worktrees no permitidos"
        echo "   Riesgo: corrupción de archivos si el IDE abre el mismo proyecto desde dos directorios"
        echo "   Alternativa: hacé stash + checkout en el mismo directorio"
        return 1
    fi

    local wt_path
    wt_path=$(_wt_path_for "$git_root" "$name")

    # Verificar que no exista ya
    if [[ -d "$wt_path" ]]; then
        echo "❌ Ya existe: $wt_path"
        return 1
    fi

    mkdir -p "$(dirname "$wt_path")"

    # Crear worktree: si el branch existe usarlo, si no crearlo nuevo
    if git -C "$git_root" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
        echo "→ Usando branch existente: $branch"
        git worktree add "$wt_path" "$branch" || return 1
    else
        echo "→ Creando branch nueva: $branch"
        git worktree add -b "$branch" "$wt_path" || return 1
    fi

    echo "✓ Worktree creado: $wt_path"

    # Abrir el agente en el flujo Herdr si está disponible.
    if [[ "${CORTEX_MULTIPLEXER:-herdr}" == "herdr" ]]; then
        echo "→ Abriendo agente para el worktree..."
        cc "$wt_path"
    fi
}

# Lista los worktrees activos del repo actual.
# Uso: wtlist
wtlist() {
    _wt_git_root &>/dev/null || { echo "❌ No estás dentro de un repo git"; return 1; }

    echo ""
    git worktree list
    echo ""
}

# Elimina un worktree por nombre y hace prune de referencias obsoletas.
# Uso: wtremove <nombre>
wtremove() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Uso: wtremove <nombre>"
        return 1
    fi

    local git_root
    git_root=$(_wt_git_root) || { echo "❌ No estás dentro de un repo git"; return 1; }

    local wt_path
    wt_path=$(_wt_path_for "$git_root" "$name")

    if [[ ! -d "$wt_path" ]]; then
        echo "❌ No encontré worktree: $wt_path"
        echo "   Usá wtlist para ver los worktrees activos"
        return 1
    fi

    git worktree remove "$wt_path" || return 1
    git worktree prune
    echo "✓ Worktree eliminado: $wt_path"
}

#endregion
