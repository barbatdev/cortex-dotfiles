#region Claude Code Helpers
# Funciones de integración con Claude Code CLI

_cmux_sidebar_refresh() {
    local target="${1:-$PWD}"
    local dotfiles_dir="${_DOTFILES_DIR:-$HOME/dev/personal/cortex-dotfiles}"
    local script="$dotfiles_dir/zsh/scripts/cmux-sidebar-refresh.sh"
    if [[ -x "$script" ]]; then
        "$script" "$target" >/dev/null 2>&1 || true
    fi
}

_workspace_name_for_path() {
    local target="${1:-$PWD}"
    local git_root
    git_root=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || true)

    if [[ -n "$git_root" ]]; then
        local repo_name
        local parent_name
        repo_name=$(basename "$git_root" | tr '.' '-')
        parent_name=$(basename "$(dirname "$git_root")" | tr '.' '-')
        printf '%s-%s' "$parent_name" "$repo_name"
    else
        basename "$target" | tr '.' '-'
    fi
}

_cmux_rename_workspace() {
    local workspace_id="$1"
    local workspace_name="$2"

    if [[ -z "$workspace_id" || -z "$workspace_name" ]]; then
        return 0
    fi

    if command -v cmux >/dev/null 2>&1; then
        # env -u descarta el socket heredado del proceso padre (cc/oc/ccb/ocb operan sobre la
        # intención explícita del usuario — el workspace destino que indicó al lanzar el comando —,
        # no sobre el focused actual; por eso solo aplicamos env -u sin --no-caller)
        env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux rename-workspace --workspace "$workspace_id" "$workspace_name" >/dev/null 2>&1 || true
    fi
}

_cortex_use_herdr_runtime() {
    [[ "${CORTEX_MULTIPLEXER:-}" == "herdr" || -n "${HERDR_ENV:-}" ]]
}

# Abrir Claude Code en tmux
# Si no está en tmux, crea una sesión nueva
cc() {
    local target="${1:-.}"
    local resolved
    resolved=$(cd "$target" 2>/dev/null && pwd)

    if [[ -z "$resolved" ]]; then
        echo "❌ Directorio no encontrado: $target"
        return 1
    fi

    if _cortex_use_herdr_runtime; then
        cd "$resolved" && claude --enable-auto-mode --dangerously-skip-permissions
        return
    fi

    if [[ -n "$CMUX_WORKSPACE_ID" ]]; then
        # Estamos dentro de cmux
        local workspace_name
        workspace_name="$(_workspace_name_for_path "$resolved")"

        # Si el directorio objetivo es el actual, lanzar claude aquí mismo
        if [[ "$resolved" == "$PWD" ]]; then
            _cmux_rename_workspace "$CMUX_WORKSPACE_ID" "$workspace_name"
            _cmux_sidebar_refresh "$resolved"
            claude --enable-auto-mode --dangerously-skip-permissions
            return
        fi

        # Directorio diferente: verificar si ya existe un workspace para no duplicar
        # env -u descarta el socket heredado: cc opera sobre el dir/workspace destino que el
        # usuario indicó explícitamente (no sobre el focused), por eso solo env -u, sin --no-caller
        local existing_id
        existing_id=$(env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux list-workspaces 2>/dev/null | jq -r --arg name "$workspace_name" '.[] | select(.title == $name) | .id' 2>/dev/null | head -1)

        if [[ -n "$existing_id" ]]; then
            # El workspace ya existe: enfocarlo sin crear uno nuevo
            _cmux_rename_workspace "$existing_id" "$workspace_name"
            env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux select-workspace --workspace "$existing_id"
            _cmux_sidebar_refresh "$resolved"
        else
            # No existe: crear workspace nuevo con claude corriendo
            if ! env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux new-workspace --name "$workspace_name" --cwd "$resolved" --command "claude --enable-auto-mode --dangerously-skip-permissions"; then
                echo "⚠️  cmux new-workspace falló, ejecutando claude en el directorio actual"
                _cmux_sidebar_refresh "$resolved"
                cd "$resolved" && claude --enable-auto-mode --dangerously-skip-permissions
            fi
        fi
    elif [[ -n "$TMUX" ]]; then
        _cmux_sidebar_refresh "$resolved"
        cd "$resolved" && claude --enable-auto-mode --dangerously-skip-permissions
    else
        # No estamos en tmux: crear sesión
        local session
        session="$(_workspace_name_for_path "$resolved")"
        if tmux has-session -t "$session" 2>/dev/null; then
            tmux attach -t "$session"
        else
            tmux new-session -d -s "$session"
            tmux send-keys -t "$session" "cd '$resolved' && claude --enable-auto-mode --dangerously-skip-permissions" Enter
            tmux attach -t "$session"
        fi
    fi
}

# Abrir OpenCode en tmux/cmux
# Mantiene el mismo patrón de uso que cc() pero usando opencode
oc() {
    local target="${1:-.}"
    local resolved
    resolved=$(cd "$target" 2>/dev/null && pwd)

    if [[ -z "$resolved" ]]; then
        echo "❌ Directorio no encontrado: $target"
        return 1
    fi

    local oc_cmd="opencode ${OPENCODE_DEFAULT_FLAGS:-}"

    if _cortex_use_herdr_runtime; then
        cd "$resolved" && eval "$oc_cmd"
        return
    fi

    if [[ -n "$CMUX_WORKSPACE_ID" ]]; then
        local workspace_name
        workspace_name="$(_workspace_name_for_path "$resolved")"

        if [[ "$resolved" == "$PWD" ]]; then
            _cmux_rename_workspace "$CMUX_WORKSPACE_ID" "$workspace_name"
            _cmux_sidebar_refresh "$resolved"
            eval "$oc_cmd"
            return
        fi

        # env -u descarta el socket heredado: oc opera sobre el dir/workspace destino que el
        # usuario indicó explícitamente (no sobre el focused), por eso solo env -u, sin --no-caller
        local existing_id
        existing_id=$(env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux list-workspaces 2>/dev/null | jq -r --arg name "$workspace_name" '.[] | select(.title == $name) | .id' 2>/dev/null | head -1)

        if [[ -n "$existing_id" ]]; then
            _cmux_rename_workspace "$existing_id" "$workspace_name"
            env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux select-workspace --workspace "$existing_id"
            _cmux_sidebar_refresh "$resolved"
        else
            if ! env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux new-workspace --name "$workspace_name" --cwd "$resolved" --command "$oc_cmd"; then
                echo "⚠️  cmux new-workspace falló, ejecutando OpenCode en el directorio actual"
                _cmux_sidebar_refresh "$resolved"
                cd "$resolved" && eval "$oc_cmd"
            fi
        fi
    elif [[ -n "$TMUX" ]]; then
        _cmux_sidebar_refresh "$resolved"
        cd "$resolved" && eval "$oc_cmd"
    else
        local session
        session="$(_workspace_name_for_path "$resolved")"
        if tmux has-session -t "$session" 2>/dev/null; then
            tmux attach -t "$session"
        else
            tmux new-session -d -s "$session"
            tmux send-keys -t "$session" "cd '$resolved' && $oc_cmd" Enter
            tmux attach -t "$session"
        fi
    fi
}

# Abrir Claude Code con bypass de permisos explícito
ccb() {
    local target="${1:-.}"
    local resolved
    resolved=$(cd "$target" 2>/dev/null && pwd)

    if [[ -z "$resolved" ]]; then
        echo "❌ Directorio no encontrado: $target"
        return 1
    fi

    local cc_cmd="claude --dangerously-skip-permissions"

    if _cortex_use_herdr_runtime; then
        cd "$resolved" && eval "$cc_cmd"
        return
    fi

    if [[ -n "$CMUX_WORKSPACE_ID" ]]; then
        local workspace_name
        workspace_name="$(_workspace_name_for_path "$resolved")"

        if [[ "$resolved" == "$PWD" ]]; then
            _cmux_rename_workspace "$CMUX_WORKSPACE_ID" "$workspace_name"
            _cmux_sidebar_refresh "$resolved"
            eval "$cc_cmd"
            return
        fi

        # env -u descarta el socket heredado: ccb opera sobre el dir/workspace destino que el
        # usuario indicó explícitamente (no sobre el focused), por eso solo env -u, sin --no-caller
        local existing_id
        existing_id=$(env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux list-workspaces 2>/dev/null | jq -r --arg name "$workspace_name" '.[] | select(.title == $name) | .id' 2>/dev/null | head -1)

        if [[ -n "$existing_id" ]]; then
            _cmux_rename_workspace "$existing_id" "$workspace_name"
            env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux select-workspace --workspace "$existing_id"
            _cmux_sidebar_refresh "$resolved"
        else
            if ! env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux new-workspace --name "$workspace_name" --cwd "$resolved" --command "$cc_cmd"; then
                echo "⚠️  cmux new-workspace falló, ejecutando Claude Code en el directorio actual"
                _cmux_sidebar_refresh "$resolved"
                cd "$resolved" && eval "$cc_cmd"
            fi
        fi
    elif [[ -n "$TMUX" ]]; then
        _cmux_sidebar_refresh "$resolved"
        cd "$resolved" && eval "$cc_cmd"
    else
        local session
        session="$(_workspace_name_for_path "$resolved")"
        if tmux has-session -t "$session" 2>/dev/null; then
            tmux attach -t "$session"
        else
            tmux new-session -d -s "$session"
            tmux send-keys -t "$session" "cd '$resolved' && $cc_cmd" Enter
            tmux attach -t "$session"
        fi
    fi
}

# Abrir OpenCode con bypass de permisos explícito
ocb() {
    local target="${1:-.}"
    local resolved
    resolved=$(cd "$target" 2>/dev/null && pwd)

    if [[ -z "$resolved" ]]; then
        echo "❌ Directorio no encontrado: $target"
        return 1
    fi

    local oc_cmd="opencode ${OPENCODE_DEFAULT_FLAGS:-}"

    if _cortex_use_herdr_runtime; then
        cd "$resolved" && eval "$oc_cmd"
        return
    fi

    if [[ -n "$CMUX_WORKSPACE_ID" ]]; then
        local workspace_name
        workspace_name="$(_workspace_name_for_path "$resolved")"

        if [[ "$resolved" == "$PWD" ]]; then
            _cmux_rename_workspace "$CMUX_WORKSPACE_ID" "$workspace_name"
            _cmux_sidebar_refresh "$resolved"
            eval "$oc_cmd"
            return
        fi

        # env -u descarta el socket heredado: ocb opera sobre el dir/workspace destino que el
        # usuario indicó explícitamente (no sobre el focused), por eso solo env -u, sin --no-caller
        local existing_id
        existing_id=$(env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux list-workspaces 2>/dev/null | jq -r --arg name "$workspace_name" '.[] | select(.title == $name) | .id' 2>/dev/null | head -1)

        if [[ -n "$existing_id" ]]; then
            _cmux_rename_workspace "$existing_id" "$workspace_name"
            env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux select-workspace --workspace "$existing_id"
            _cmux_sidebar_refresh "$resolved"
        else
            if ! env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux new-workspace --name "$workspace_name" --cwd "$resolved" --command "$oc_cmd"; then
                echo "⚠️  cmux new-workspace falló, ejecutando OpenCode en el directorio actual"
                _cmux_sidebar_refresh "$resolved"
                cd "$resolved" && eval "$oc_cmd"
            fi
        fi
    elif [[ -n "$TMUX" ]]; then
        _cmux_sidebar_refresh "$resolved"
        cd "$resolved" && eval "$oc_cmd"
    else
        local session
        session="$(_workspace_name_for_path "$resolved")"
        if tmux has-session -t "$session" 2>/dev/null; then
            tmux attach -t "$session"
        else
            tmux new-session -d -s "$session"
            tmux send-keys -t "$session" "cd '$resolved' && $oc_cmd" Enter
            tmux attach -t "$session"
        fi
    fi
}

# Abrir Claude Code con contexto inicial en tmux
ccx() {
    local context="$1"
    local target="${2:-.}"

    if [[ -z "$context" ]]; then
        echo "Uso: ccx <contexto> [directorio]"
        return 1
    fi

    local resolved
    resolved=$(cd "$target" 2>/dev/null && pwd)

    if [[ -z "$resolved" ]]; then
        echo "❌ Directorio no encontrado: $target"
        return 1
    fi

    if _cortex_use_herdr_runtime; then
        cd "$resolved" && echo "$context" | claude
        return
    fi

    if [[ -n "$CMUX_WORKSPACE_ID" ]]; then
        # Estamos dentro de cmux: escribir contexto a tempfile y abrir workspace propio
        local workspace_name
        workspace_name="$(_workspace_name_for_path "$resolved")"

        # Archivo de contexto en ~/.claude/ para garantizar accesibilidad desde el workspace nuevo
        local ctxfile="$HOME/.claude/ccx-ctx-$$.txt"
        echo "$context" > "$ctxfile"
        chmod 600 "$ctxfile"

        # Crear workspace nuevo — el cleanup va dentro del comando para que
        # el archivo siga existiendo cuando cmux lo lea en el workspace nuevo
        # env -u descarta el socket heredado: ccx opera sobre el workspace destino explícito
        if env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux new-workspace --name "$workspace_name" --cwd "$resolved" --command "sh -c 'claude < $ctxfile; rm -f $ctxfile'"; then
            : # limpieza la hace el comando en el workspace nuevo
        else
            # cmux falló: limpiar archivo y ejecutar claude directo con el contexto
            rm -f "$ctxfile"
            echo "⚠️  cmux new-workspace falló, ejecutando claude en el directorio actual"
            cd "$resolved" && echo "$context" | claude
        fi
    elif [[ -n "$TMUX" ]]; then
        cd "$resolved" && echo "$context" | claude
    else
        local session
        session="$(_workspace_name_for_path "$resolved")"
        if tmux has-session -t "$session" 2>/dev/null; then
            tmux attach -t "$session"
        else
            tmux new-session -d -s "$session"
            tmux send-keys -t "$session" "cd '$resolved' && echo ${(q)context} | claude" Enter
            tmux attach -t "$session"
        fi
    fi
}

# Navegar al Claude workspace
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
        echo "📂 Navegando a: $target"
    else
        echo "❌ Directorio no encontrado: $target"
        return 1
    fi
}

# Copiar contexto de código al clipboard para Claude
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

    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "⚠️  Archivo no encontrado: $file"
            continue
        fi

        local ext="${file##*.}"
        context+="\`\`\`$ext\n"
        context+="// File: $file\n"

        if $with_numbers; then
            local n=1
            while IFS= read -r line; do
                context+=$(printf "%4d: %s\n" "$n" "$line")
                (( n++ ))
            done < "$file"
        else
            context+="$(cat "$file")\n"
        fi

        context+="\`\`\`\n\n"
    done

    echo -e "$context" | pbcopy
    echo "✓ Contexto copiado al clipboard (${#files[@]} archivo$([ ${#files[@]} -ne 1 ] && echo 's'))"
}

#endregion
