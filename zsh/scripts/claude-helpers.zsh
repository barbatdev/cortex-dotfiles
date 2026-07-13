#region Claude Code Helpers

_cmux_sidebar_refresh() {
    local target="${1:-$PWD}"
    local workspace="${2:-}"
    local script="${_DOTFILES_DIR:-$HOME/.cortex/cortex-dotfiles}/zsh/scripts/cmux-sidebar-refresh.sh"

    [[ -x "$script" ]] && "$script" "$target" "$workspace" >/dev/null 2>&1 || true
}

_cortex_resolve_target() {
    local target="${1:-.}"
    local resolved

    resolved=$(cd -q "$target" 2>/dev/null && pwd) || {
        echo "Directorio no encontrado: $target"
        return 1
    }
    printf '%s\n' "$resolved"
}

_cortex_run_agent() {
    local target="$1"
    shift
    local -a agent_command=("$@")
    local command_string=""
    local arg created workspace

    if [[ "${CORTEX_MULTIPLEXER:-cmux}" == "cmux" && -n "${CMUX_WORKSPACE_ID:-}" && "$target" != "$PWD" ]]; then
        for arg in "${agent_command[@]}"; do
            command_string+="${(q)arg} "
        done
        created=$(cmux workspace create --cwd "$target" --command "$command_string" --json) || return 1
        workspace=$(jq -er '.workspace_ref // .workspace_id' <<<"$created") || return 1
        _cmux_sidebar_refresh "$target" "$workspace"
        return
    fi

    _cmux_sidebar_refresh "$target"
    (cd -q "$target" && command "${agent_command[@]}")
}

# Abre Claude Code en el path indicado.
# Uso: cc [path]
cc() {
    local resolved ctxfile
    resolved=$(_cortex_resolve_target "${1:-.}") || return
    _cortex_run_agent "$resolved" claude --enable-auto-mode --dangerously-skip-permissions
}

# Abre OpenCode en el path indicado.
# Uso: oc [path]
oc() {
    local resolved
    local -a flags
    resolved=$(_cortex_resolve_target "${1:-.}") || return
    flags=(${=${OPENCODE_DEFAULT_FLAGS:-}})
    _cortex_run_agent "$resolved" opencode "${flags[@]}"
}

# Abre Claude Code con bypass explícito de permisos.
# Uso: ccb [path]
ccb() {
    local resolved
    resolved=$(_cortex_resolve_target "${1:-.}") || return
    _cortex_run_agent "$resolved" claude --dangerously-skip-permissions
}

# Alias simétrico de OpenCode; sus flags se configuran con OPENCODE_DEFAULT_FLAGS.
# Uso: ocb [path]
ocb() {
    oc "$@"
}

# Abre Claude Code con contexto inicial.
# Uso: ccx <contexto> [path]
ccx() {
    local context="$1"
    local resolved

    if [[ -z "$context" ]]; then
        echo "Uso: ccx <contexto> [directorio]"
        return 1
    fi
    resolved=$(_cortex_resolve_target "${2:-.}") || return
    ctxfile=$(mktemp "${TMPDIR:-/tmp}/cortex-ccx.XXXXXX") || return 1
    chmod 600 "$ctxfile"
    printf '%s\n' "$context" > "$ctxfile"
    _cortex_run_agent "$resolved" sh -c 'claude < "$1"; status=$?; rm -f "$1"; exit $status' sh "$ctxfile" || {
        rm -f "$ctxfile"
        return 1
    }
}

# Navega al workspace principal o a uno de sus subdirectorios.
# Uso: ccd [subpath]
ccd() {
    local subpath="${1:-}"
    local workspace="${WORKSPACE_DIR:-$HOME/dev}"
    local target="${workspace}${subpath:+/$subpath}"

    if [[ -d "$target" ]]; then
        cd "$target"
        echo "Navegando a: $target"
    else
        echo "Directorio no encontrado: $target"
        return 1
    fi
}

# Copia archivos como bloques Markdown al clipboard.
# Uso: ccclip <archivo...> [-n|--line-numbers]
ccclip() {
    if [[ $# -eq 0 ]]; then
        echo "Uso: ccclip <archivo1> [archivo2 ...] [-n|--line-numbers]"
        return 1
    fi

    local with_numbers=false
    local -a files=()
    local arg file ext context=""
    for arg in "$@"; do
        case "$arg" in
            -n|--line-numbers) with_numbers=true ;;
            *) files+=("$arg") ;;
        esac
    done

    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "Archivo no encontrado: $file"
            continue
        fi

        ext="${file##*.}"
        context+="\`\`\`$ext\n// File: $file\n"
        if $with_numbers; then
            context+="$(nl -ba "$file")\n"
        else
            context+="$(<"$file")\n"
        fi
        context+="\`\`\`\n\n"
    done

    printf '%b' "$context" | pbcopy
    echo "Contexto copiado al clipboard (${#files[@]} archivos)"
}

#endregion
