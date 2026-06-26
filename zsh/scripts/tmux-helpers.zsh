# tmux-helpers.zsh — Helpers para gestión de sesiones tmux

# Alias base
alias t="tmux"

# Listar sesiones activas
tl() {
    tmux ls 2>/dev/null || echo "No hay sesiones tmux activas"
}

# Attach a una sesión (o crearla si no existe)
ta() {
    local session="${1:-main}"
    tmux attach -t "$session" 2>/dev/null || tmux new-session -s "$session"
}

# Nueva sesión con nombre
tn() {
    local session="${1:?Uso: tn <nombre>}"
    tmux new-session -s "$session"
}

# Matar una sesión
tk() {
    local session="${1:?Uso: tk <nombre>}"
    tmux kill-session -t "$session" && echo "✓ Sesión '$session' terminada"
}

# Sesión de desarrollo: nombre = basename del directorio actual
# Uso: cd ~/dev/work/myproject && tdev
tdev() {
    local session
    session="$(basename "$PWD" | tr '.' '-')"
    ta "$session"
}

# Sesión de Claude Code en tmux
# Uso: cd ~/dev/work/myproject && tcc
tcc() {
    local session
    session="$(basename "$PWD" | tr '.' '-')"

    if tmux has-session -t "$session" 2>/dev/null; then
        tmux attach -t "$session"
        return
    fi

    tmux new-session -d -s "$session"
    tmux send-keys -t "$session" "claude" Enter
    tmux attach -t "$session"
}
