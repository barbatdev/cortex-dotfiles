#region Claude Code Helpers
# Funciones de integración con Claude Code/OpenCode. Herdr maneja sesiones, panes y persistencia.

_workspace_name_for_path() {
    local target="${1:-$PWD}"
    local git_root
    git_root=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || true)

    if [[ -n "$git_root" ]]; then
        local repo_name parent_name
        repo_name=$(basename "$git_root" | tr '.' '-')
        parent_name=$(basename "$(dirname "$git_root")" | tr '.' '-')
        printf '%s-%s' "$parent_name" "$repo_name"
    else
        basename "$target" | tr '.' '-'
    fi
}

_resolve_dir_or_fail() {
    local target="${1:-.}"
    local resolved
    resolved=$(cd -q "$target" >/dev/null 2>&1 && pwd) || {
        echo "Directorio no encontrado: $target"
        return 1
    }
    printf '%s' "$resolved"
}

# Abrir Claude Code en el directorio actual/pasado.
cc() {
    local resolved
    resolved=$(_resolve_dir_or_fail "${1:-.}") || return 1
    cd "$resolved" && claude --enable-auto-mode --dangerously-skip-permissions
}

# Abrir OpenCode en el directorio actual/pasado.
oc() {
    local resolved
    resolved=$(_resolve_dir_or_fail "${1:-.}") || return 1
    cd "$resolved" && opencode ${OPENCODE_DEFAULT_FLAGS:-}
}

# Abrir Claude Code con bypass de permisos explícito.
ccb() {
    local resolved
    resolved=$(_resolve_dir_or_fail "${1:-.}") || return 1
    cd "$resolved" && claude --dangerously-skip-permissions
}

# Abrir OpenCode con flags por defecto.
ocb() {
    oc "${1:-.}"
}

# Abrir Claude Code con contexto inicial.
ccx() {
    local context="$1"
    local target="${2:-.}"

    if [[ -z "$context" ]]; then
        echo "Uso: ccx <contexto> [directorio]"
        return 1
    fi

    local resolved
    resolved=$(_resolve_dir_or_fail "$target") || return 1
    cd "$resolved" && echo "$context" | claude
}

# Navegar al workspace principal.
ccd() {
    local subpath="${1:-}"
    local workspace="${WORKSPACE_DIR:-$HOME/dev}"
    local target

    if [[ -n "$subpath" ]]; then
        target="$workspace/$subpath"
    else
        target="$workspace"
    fi

    if [[ -d "$target" ]]; then
        cd "$target"
        echo "Navegando a: $target"
    else
        echo "Directorio no encontrado: $target"
        return 1
    fi
}

# Copiar contexto de código al clipboard para Claude.
ccclip() {
    if [[ $# -eq 0 ]]; then
        echo "Uso: ccclip <archivo1> [archivo2 ...] [-n|--line-numbers]"
        return 1
    fi

    local with_numbers=false
    local files=()

    for arg in "$@"; do
        case "$arg" in
            -n|--line-numbers) with_numbers=true ;;
            *) files+=("$arg") ;;
        esac
    done

    local context=""
    local file ext n line

    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "Archivo no encontrado: $file"
            continue
        fi

        ext="${file##*.}"
        context+="\`\`\`$ext\n"
        context+="// File: $file\n"

        if $with_numbers; then
            n=1
            while IFS= read -r line; do
                context+=$(printf "%4d: %s\n" "$n" "$line")
                (( n++ ))
            done < "$file"
        else
            context+="$(<"$file")\n"
        fi

        context+="\`\`\`\n\n"
    done

    if command -v pbcopy >/dev/null 2>&1; then
        print -r -- "$context" | pbcopy
    elif command -v wl-copy >/dev/null 2>&1; then
        print -r -- "$context" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        print -r -- "$context" | xclip -selection clipboard
    else
        print -r -- "$context"
        echo "Clipboard no disponible; imprimí el contexto en stdout"
        return 1
    fi

    echo "Contexto copiado al clipboard (${#files[@]} archivo$([ ${#files[@]} -ne 1 ] && echo 's'))"
}

#endregion
