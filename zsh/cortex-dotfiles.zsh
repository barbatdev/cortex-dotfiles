#region Header
# Dev Zsh Profile — macOS + Ghostty
# YOUR_NAME - YOUR_ORG
#endregion

#region Performance
zmodload zsh/datetime
_PROFILE_START=$EPOCHREALTIME
#endregion

#region Brew
if command -v brew &>/dev/null; then
    eval "$(brew shellenv)"
fi
#endregion

#region PATH
export PATH="$HOME/.local/bin:$PATH"
[[ -d "/Applications/cmux.app/Contents/Resources/bin" ]] && export PATH="/Applications/cmux.app/Contents/Resources/bin:$PATH"
#endregion

#region Zsh Options
# Historia
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS       # no guardar duplicados consecutivos
setopt HIST_IGNORE_SPACE      # no guardar comandos que empiezan con espacio
setopt SHARE_HISTORY          # compartir historia entre sesiones

# Navegación
setopt AUTO_CD                # escribir un directorio lo hace cd
setopt AUTO_PUSHD             # cd empuja al stack (podés usar popd)
setopt PUSHD_SILENT           # sin output en pushd/popd

# Completado
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # case insensitive

# Sin beep
setopt NO_BEEP
#endregion

#region Editor
if command -v nvim &>/dev/null; then
    export EDITOR="$(command -v nvim)"
elif command -v vim &>/dev/null; then
    export EDITOR="$(command -v vim)"
else
    export EDITOR="nano"
fi
export VISUAL="$EDITOR"
#endregion

#region Environment Variables
# Workspace principal de desarrollo
export WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/dev}"
export BARBATDEV_DIR="${BARBATDEV_DIR:-$WORKSPACE_DIR/barbatdev}"
export CLAUDE_CODE_EFFORT_LEVEL=high
export CORTEX_DOTFILES_DIR="${CORTEX_DOTFILES_DIR:-$BARBATDEV_DIR/cortex/cortex-dotfiles}"

# Proyectos de la organización
export WORK_PROJECTS_DIR="${WORK_PROJECTS_DIR:-$BARBATDEV_DIR/innit}"
export PERSONAL_PROJECTS_DIR="${PERSONAL_PROJECTS_DIR:-$BARBATDEV_DIR/products}"
export INNIT_DIR="${INNIT_DIR:-$BARBATDEV_DIR/innit}"

# Screenshots (configurable en local/env.zsh)
export SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-$HOME/Screenshots}"
#endregion

#region Git Aliases
alias g="git"
gs()  { git status "$@" }
ga()  { git add "$@" }
gc()  { git commit -m "$@" }
gp()  { git push "$@" }
gl()  { git log --oneline --graph --decorate --all }
gd()  { git diff "$@" }
gco() { git checkout "$@" }
gb()  { git branch "$@" }
gpl() { git pull "$@" }
gf()  { git fetch "$@" }
gst() { git stash "$@" }
#endregion

#region Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

_go_dev_dir() {
    local target="$1"
    if [[ -d "$target" ]]; then
        cd "$target"
    else
        echo "❌ Directorio no encontrado: $target"
        return 1
    fi
}

_go_first_existing_dir() {
    local target
    for target in "$@"; do
        if [[ -d "$target" ]]; then
            cd "$target"
            return
        fi
    done
    echo "❌ Directorio no encontrado: $1"
    return 1
}

dev()         { _go_dev_dir "$HOME/dev"; }
barbat()      { _go_dev_dir "$BARBATDEV_DIR"; }
cowork()      { _go_first_existing_dir "$WORK_PROJECTS_DIR" "$BARBATDEV_DIR/innit"; }
personal()    { _go_first_existing_dir "$PERSONAL_PROJECTS_DIR" "$BARBATDEV_DIR/products"; }
tools()       { _go_dev_dir "$BARBATDEV_DIR/tools"; }
worktrees()   { _go_dev_dir "$HOME/dev/worktrees"; }
work()        { _go_first_existing_dir "$WORK_PROJECTS_DIR" "$BARBATDEV_DIR/innit"; }
innit()       { _go_first_existing_dir "$INNIT_DIR" "$BARBATDEV_DIR/innit"; }
innit-apis()  { _go_first_existing_dir "${INNIT_APIS_DIR:-$INNIT_DIR}" "$INNIT_DIR"; }
innit-mobile(){ _go_first_existing_dir "${INNIT_MOBILE_DIR:-$INNIT_DIR}" "$INNIT_DIR"; }
innit-webs()  { _go_first_existing_dir "${INNIT_WEBS_DIR:-$INNIT_DIR}" "$INNIT_DIR"; }
innit-pcsoft(){ _go_first_existing_dir "${INNIT_PCSOFT_DIR:-$INNIT_DIR}" "$INNIT_DIR"; }
dotfiles()    { _go_dev_dir "${_DOTFILES_DIR:-$CORTEX_DOTFILES_DIR}"; }
#endregion

#region System Aliases
alias c="clear"
alias o="open"
alias reload="source ~/.zshrc && echo 'Profile recargado!'"

# ls mejorado (usa eza si está instalado)
if command -v eza &>/dev/null; then
    alias ll="eza -la --icons --git"
    alias la="eza -la --icons --git --all"
    alias lt="eza --tree --icons --level=2"
else
    alias ll="ls -lah"
    alias la="ls -lah -A"
fi
#endregion

#region Clipboard
# Copiar texto al clipboard
ccp() {
    if [[ -p /dev/stdin ]]; then
        pbcopy
    else
        echo -n "$*" | pbcopy
    fi
    echo "✓ Copiado al clipboard"
}

# Copiar path al clipboard
cppath() {
    local path="${1:-.}"
    local resolved
    resolved=$(cd "$path" 2>/dev/null && pwd || realpath "$path" 2>/dev/null || echo "$path")
    echo -n "$resolved" | pbcopy
    echo "✓ Path copiado: $resolved"
}
#endregion

#region Developer Tools
# Buscar archivos por nombre
ff() {
    local pattern="${1:?Uso: ff <pattern>}"
    find . -name "*$pattern*" -not -path "*/\.*" 2>/dev/null
}

# IP pública
myip() {
    curl -s "https://api.ipify.org"
    echo
}

# Mostrar el logo de RefactorIA en Braille Unicode bajo demanda.
refactoria() {
    local logo="${_DOTFILES_DIR:-$HOME/dev/personal/cortex-dotfiles}/assets/refactoria-braille.txt"
    if [[ -f "$logo" ]]; then
        cat "$logo"
    else
        echo "Logo RefactorIA no encontrado: $logo"
        return 1
    fi
}

# Matar proceso por nombre
pkill-name() {
    local name="${1:?Uso: pkill-name <nombre>}"
    pkill -f "$name" && echo "✓ Proceso '$name' terminado" || echo "No se encontró proceso: $name"
}
#endregion

#region Edit
# Editar archivos con el mejor editor disponible
edit() {
    local path="${1:?Uso: edit <archivo>}"

    # Verificar si es archivo PCSoft antes de abrir
    if is-pcsoft-forbidden "$path" 2>/dev/null; then
        echo "⛔ ARCHIVO PCSOFT PROHIBIDO: $path"
        echo "   La modificación externa corrompe el archivo permanentemente."
        echo "   Usá el WinDev/WebDev IDE."
        return 1
    fi

    if is-pcsoft-editable "$path" 2>/dev/null; then
        echo "⚠️  ARCHIVO PCSOFT EDITABLE: $path"
        echo "   Solo modificar bloques 'code : |1+'. El IDE debe estar CERRADO."
        echo -n "   ¿Continuar? [s/N] "
        read -r confirm
        [[ "$confirm" =~ ^[sS]$ ]] || return 0
    fi

    "$EDITOR" "$path"
}

alias e="edit"
function ep { edit "$_DOTFILES_DIR/zsh/cortex-dotfiles.zsh" }
#endregion

#region Source Scripts
_ZSHRC_SOURCE="${(%):-%x}"
if [[ -L "$_ZSHRC_SOURCE" ]]; then
    _ZSHRC_SOURCE="$(readlink "$_ZSHRC_SOURCE")"
fi
_DOTFILES_DIR="$(cd "$(dirname "$_ZSHRC_SOURCE")/.." && pwd)"
_SCRIPTS_DIR="$_DOTFILES_DIR/zsh/scripts"

if [[ -d "$_SCRIPTS_DIR" ]]; then
    [[ -f "$_SCRIPTS_DIR/pcsoft-helpers.zsh" ]] && source "$_SCRIPTS_DIR/pcsoft-helpers.zsh"
    [[ -f "$_SCRIPTS_DIR/screenshots.zsh" ]]    && source "$_SCRIPTS_DIR/screenshots.zsh"
    [[ -f "$_SCRIPTS_DIR/claude-helpers.zsh" ]] && source "$_SCRIPTS_DIR/claude-helpers.zsh"
    [[ -f "$_SCRIPTS_DIR/git-helpers.zsh" ]]    && source "$_SCRIPTS_DIR/git-helpers.zsh"
    [[ -f "$_SCRIPTS_DIR/ssh-helpers.zsh" ]]    && source "$_SCRIPTS_DIR/ssh-helpers.zsh"
    [[ -f "$_SCRIPTS_DIR/herdr-helpers.zsh" ]]  && source "$_SCRIPTS_DIR/herdr-helpers.zsh"
    [[ -f "$_SCRIPTS_DIR/tmux-helpers.zsh" ]]   && source "$_SCRIPTS_DIR/tmux-helpers.zsh"
    [[ -f "$_SCRIPTS_DIR/worktree-helpers.zsh" ]] && source "$_SCRIPTS_DIR/worktree-helpers.zsh"
    [[ -f "$_SCRIPTS_DIR/agent-state.sh" ]] && source "$_SCRIPTS_DIR/agent-state.sh"
fi

alias cortex.agent_state.v1="cortex_agent_state"
alias agent-state="cortex_agent_state"
#endregion

#region Local Overrides
# Cargar configuración local (gitignored: paths personales, tokens, etc.)
_LOCAL_ENV="$_DOTFILES_DIR/local/env.zsh"
[[ -f "$_LOCAL_ENV" ]] && source "$_LOCAL_ENV"
#endregion

#region Atuin
# Historial de shell con búsqueda avanzada (reemplaza Ctrl+R)
if command -v atuin &>/dev/null; then
    eval "$(atuin init zsh)"
fi
#endregion

#region Starship
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi
#endregion

#region Welcome
_welcome() {
    local ms
    ms=$(printf "%.0f" "$(( (EPOCHREALTIME - _PROFILE_START) * 1000 ))")

    echo ""
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║      Dev Environment                 ║"
    echo "  ╠══════════════════════════════════════╣"
    printf "  ║  ⚡ Cargado en \033[1;32m%sms\033[0m\n" "$ms"
    printf "  ║  🕐 \033[1;34m%s\033[0m\n" "$(date '+%H:%M:%S')"
    echo "  ╚══════════════════════════════════════╝"
    echo ""
    echo "  \033[90mescribí\033[0m \033[1;33mhelp-profile\033[0m \033[90mpara ver comandos disponibles\033[0m"
    echo ""
}

help-profile() {
    local T="\033[1;33m"  # título (amarillo)
    local C="\033[1;36m"  # comando (cyan)
    local R="\033[0m"     # reset

    echo ""
    echo "${T}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
    echo "${T}  Zsh — Referencia rápida                 ${R}"
    echo "${T}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"

    echo "\n${T}Git identidades${R}"
    echo "  ${C}git-workdev       ${R}Setear identidad de trabajo en repo actual"
    echo "  ${C}git-personaldev   ${R}Setear identidad personal en repo actual"
    echo "  ${C}git-whoami        ${R}Ver identidad y remote configurados"
    echo "  ${C}clone-workdev     ${R}Clonar repo de cuenta de trabajo"
    echo "  ${C}clone-personaldev ${R}Clonar repo de cuenta personal"

    echo "\n${T}Navegación${R}"
    echo "  ${C}dev               ${R}cd ~/dev"
    echo "  ${C}barbat            ${R}cd ~/dev/barbat"
    echo "  ${C}cowork            ${R}cd ~/dev/cowork"
    echo "  ${C}personal          ${R}cd ~/dev/personal"
    echo "  ${C}tools             ${R}cd ~/dev/tools"
    echo "  ${C}worktrees         ${R}cd ~/dev/worktrees"
    echo "  ${C}work              ${R}cd ~/dev/work"
    echo "  ${C}innit            ${R}cd ~/dev/innit"
    echo "  ${C}innit-apis       ${R}cd ~/dev/innit/apis"
    echo "  ${C}innit-mobile     ${R}cd ~/dev/innit/mobile"
    echo "  ${C}innit-webs       ${R}cd ~/dev/innit/webs"
    echo "  ${C}innit-pcsoft     ${R}cd ~/dev/innit/pcsoft"
    echo "  ${C}dotfiles         ${R}cd ~/dev/personal/dotfiles"
    echo "  ${C}.., ..., ....     ${R}Subir 1, 2 o 3 niveles"

    echo "\n${T}Claude Code${R}"
    echo "  ${C}cc [path]         ${R}Abrir Claude Code en directorio"
    echo "  ${C}oc [path]         ${R}Abrir OpenCode en directorio"
    echo "  ${C}ccx <ctx> [p]     ${R}Claude Code con contexto inicial"
    echo "  ${C}ccd [sub]         ${R}Navegar al Claude workspace"
    echo "  ${C}ccclip <files>    ${R}Copiar código al clipboard"

    echo "\n${T}Tmux — sesiones${R}"
    echo "  ${C}tcc               ${R}Abrir Claude Code + lazygit (layout automático)"
    echo "  ${C}tdev              ${R}Sesión con nombre del directorio actual"
    echo "  ${C}ta [nombre]       ${R}Attach a sesión (o crearla)"
    echo "  ${C}tn <nombre>       ${R}Nueva sesión con nombre"
    echo "  ${C}tl                ${R}Listar sesiones activas"
    echo "  ${C}tk <nombre>       ${R}Matar sesión"

    echo "\n${T}Tmux — keybindings${R}"
    echo "  ${C}Ctrl+A R          ${R}Recargar config"
    echo "  ${C}Ctrl+A Space      ${R}Ver todos los keybindings (which-key)"
    echo "  ${C}Ctrl+A |          ${R}Split vertical"
    echo "  ${C}Ctrl+A -          ${R}Split horizontal"
    echo "  ${C}Ctrl+A hjkl       ${R}Navegar entre paneles"
    echo "  ${C}Ctrl+A Ctrl+S     ${R}Guardar sesiones (resurrect)"
    echo "  ${C}Ctrl+A Ctrl+R     ${R}Restaurar sesiones (resurrect)"
    echo "  ${C}Option+G          ${R}Popup flotante (scratch)"
    echo ""
}

_welcome
#endregion

# opencode
export PATH=$HOME/.opencode/bin:$PATH

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# bun completions
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"
export PATH="/opt/homebrew/opt/bc/bin:$PATH"
