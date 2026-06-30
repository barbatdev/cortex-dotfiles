# tmux-helpers.zsh — Compat aliases sobre Zellij

# Alias base: mantenemos la memoria muscular `t*`, pero el backend default es Zellij.
alias t="zellij"

# Listar sesiones activas
tl() {
    zellij list-sessions 2>/dev/null || echo "No hay sesiones Zellij activas"
}

# Attach a una sesión (o crearla si no existe)
ta() {
    local session="${1:-main}"
    local layout_file
    session="$(_zellij_context_label):$session"
    layout_file="$(_zellij_default_layout)"
    if _zellij_session_exists "$session"; then
        zellij attach "$session"
    elif [[ -n "$layout_file" ]]; then
        zellij --session "$session" --layout "$layout_file"
    else
        zellij attach "$session" --create
    fi
}

# Nueva sesión con nombre
tn() {
    local session="${1:?Uso: tn <nombre>}"
    local layout_file
    session="$(_zellij_context_label):$session"
    layout_file="$(_zellij_default_layout)"
    if [[ -n "$layout_file" ]]; then
        zellij --session "$session" --layout "$layout_file"
    else
        zellij attach "$session" --create
    fi
}

# Matar una sesión
tk() {
    local session="${1:?Uso: tk <nombre>}"
    [[ "$session" == *:* ]] || session="$(_zellij_context_label):$session"
    zellij delete-session "$session" --force && echo "✓ Sesión '$session' terminada"
}

# Sesión de desarrollo: nombre = basename del directorio actual
# Uso: cd ~/dev/work/myproject && tdev
tdev() {
    local session
    session="$(basename "$PWD" | tr '.' '-')"
    ta "$session"
}

# Sesión de Claude Code en Zellij
# Uso: cd ~/dev/work/myproject && tcc
tcc() {
    local session
    session="$(basename "$PWD" | tr '.' '-')"
    CORTEX_MULTIPLEXER=zellij cc "$PWD"
}
