#!/bin/bash
# install.sh — Instalador de dotfiles macOS
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║      dotfiles — Instalador macOS     ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# --- Verificar dependencias base ---
if ! command -v brew &>/dev/null; then
    echo "❌ Homebrew no está instalado. Instalá desde https://brew.sh"
    exit 1
fi

if ! command -v starship &>/dev/null; then
    echo "📦 Instalando starship..."
    brew install starship
fi

# --- Instalar herramientas opcionales ---
echo "📦 Verificando herramientas..."

karabiner_app_exists() {
    [[ -d "/Applications/Karabiner-Elements.app" || -d "$HOME/Applications/Karabiner-Elements.app" ]]
}

karabiner_cli_available() {
    command -v karabiner_cli &>/dev/null || [[ -x "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli" ]]
}

karabiner_cli_path() {
    if command -v karabiner_cli &>/dev/null; then
        command -v karabiner_cli
    elif [[ -x "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli" ]]; then
        printf '%s\n' "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
    fi
}

if ! command -v micro &>/dev/null; then
    echo "  → Instalando micro (editor terminal)..."
    brew install micro
else
    echo "  ✓ micro ya instalado"
fi

if ! command -v eza &>/dev/null; then
    echo "  → Instalando eza (ls mejorado)..."
    brew install eza
else
    echo "  ✓ eza ya instalado"
fi

if ! command -v zellij &>/dev/null; then
    echo "  → Instalando zellij (multiplexor de terminal)..."
    brew install zellij
else
    echo "  ✓ zellij ya instalado"
fi

if ! command -v lazygit &>/dev/null; then
    echo "  → Instalando lazygit (git TUI)..."
    brew install lazygit
else
    echo "  ✓ lazygit ya instalado"
fi

if ! command -v sketchybar &>/dev/null; then
    echo "  → Instalando sketchybar (barra macOS)..."
    brew install sketchybar
else
    echo "  ✓ sketchybar ya instalado"
fi

if ! command -v yabai &>/dev/null; then
    echo "  → Instalando yabai (window manager macOS)..."
    brew tap koekeishiya/formulae
    brew install yabai
else
    echo "  ✓ yabai ya instalado"
fi

if ! command -v skhd &>/dev/null; then
    echo "  → Instalando skhd (hotkeys macOS)..."
    brew tap koekeishiya/formulae
    brew install skhd
else
    echo "  ✓ skhd ya instalado"
fi

if ! karabiner_cli_available && ! karabiner_app_exists; then
    echo "  → Instalando Karabiner-Elements..."
    brew install --cask karabiner-elements
else
    echo "  ✓ Karabiner-Elements ya instalado"
fi

# --- Fuentes ---
echo ""
echo "📦 Verificando fuentes..."

if ! ls "$HOME/Library/Fonts/FiraCodeNerdFont"* &>/dev/null 2>&1; then
    echo "  → Instalando FiraCode Nerd Font..."
    brew install --cask font-fira-code-nerd-font
    echo "  ✓ FiraCode Nerd Font instalada"
else
    echo "  ✓ FiraCode Nerd Font ya instalada"
fi

mkdir -p "$HOME/Library/Fonts"
cp "$DOTFILES/fonts/FiraCodeNerdFontMonoBeard-Reg.ttf" "$HOME/Library/Fonts/FiraCodeNerdFontMonoBeard-Reg.ttf"
echo "  ✓ FiraCode Nerd Font Mono Beard instalada"

# --- Backup de configs existentes ---
echo ""
echo "💾 Haciendo backup de configs existentes..."

backup_if_exists() {
    local src="$1"
    if [[ -e "$src" && ! -L "$src" ]]; then
        local backup="${src}.bak_${TIMESTAMP}"
        cp "$src" "$backup"
        echo "  → Backup: $backup"
    fi
}

backup_karabiner_if_exists() {
    local src="$HOME/.config/karabiner/karabiner.json"
    if [[ -e "$src" || -L "$src" ]]; then
        local backup="${src}.bak_${TIMESTAMP}"
        if [[ -L "$src" ]]; then
            cp -P "$src" "$backup"
        else
            cp "$src" "$backup"
        fi
        echo "  → Backup: $backup"
    fi
}

backup_if_exists "$HOME/.zshrc"
backup_if_exists "$HOME/.npmrc"
backup_if_exists "$HOME/Library/Preferences/pnpm/rc"
backup_if_exists "$HOME/.bunfig.toml"
backup_if_exists "$HOME/.config/uv/uv.toml"
backup_if_exists "$HOME/.config/starship.toml"
backup_if_exists "$HOME/.config/ghostty/config"
backup_if_exists "$HOME/.config/zellij/config.kdl"
backup_if_exists "$HOME/.config/zellij/layouts/innit.kdl"
backup_if_exists "$HOME/.claude/statusline.sh"
backup_if_exists "$HOME/.config/lazygit/config.yml"
backup_if_exists "$HOME/.config/sketchybar"
backup_if_exists "$HOME/.config/yabai/yabairc"
backup_if_exists "$HOME/.yabairc"
backup_if_exists "$HOME/.config/skhd/skhdrc"
backup_if_exists "$HOME/.skhdrc"
backup_karabiner_if_exists

# --- Crear symlinks ---
echo ""
echo "🔗 Creando symlinks..."

create_symlink() {
    local src="$1"
    local dst="$2"
    mkdir -p "$(dirname "$dst")"
    # -n evita que ln dereferencie un symlink-a-directorio existente y cree
    # un link adentro (caso ghostty/shaders → loop shaders/shaders)
    ln -sfn "$src" "$dst"
    echo "  ✓ $dst → $src"
}

create_symlink "$DOTFILES/zsh/zshrc"              "$HOME/.zshrc"
create_symlink "$DOTFILES/npm/npmrc"               "$HOME/.npmrc"
create_symlink "$DOTFILES/pnpm/rc"                 "$HOME/Library/Preferences/pnpm/rc"
create_symlink "$DOTFILES/bun/bunfig.toml"         "$HOME/.bunfig.toml"
create_symlink "$DOTFILES/uv/uv.toml"              "$HOME/.config/uv/uv.toml"
create_symlink "$DOTFILES/starship/starship.toml"  "$HOME/.config/starship.toml"
create_symlink "$DOTFILES/ghostty/config"          "$HOME/.config/ghostty/config"
create_symlink "$DOTFILES/ghostty/shaders"         "$HOME/.config/ghostty/shaders"
create_symlink "$DOTFILES/zellij/config.kdl"       "$HOME/.config/zellij/config.kdl"
create_symlink "$DOTFILES/zellij/layouts/innit.kdl" "$HOME/.config/zellij/layouts/innit.kdl"
chmod +x "$DOTFILES/claude/statusline.sh"
create_symlink "$DOTFILES/claude/statusline.sh"    "$HOME/.claude/statusline.sh"
create_symlink "$DOTFILES/micro/settings.json"     "$HOME/.config/micro/settings.json"
create_symlink "$DOTFILES/lazygit/config.yml"      "$HOME/.config/lazygit/config.yml"
chmod +x "$DOTFILES/sketchybar/sketchybarrc" "$DOTFILES/sketchybar/plugins"/*.sh
create_symlink "$DOTFILES/sketchybar"              "$HOME/.config/sketchybar"
chmod +x "$DOTFILES/yabai/yabairc"
create_symlink "$DOTFILES/yabai/yabairc"           "$HOME/.config/yabai/yabairc"
create_symlink "$DOTFILES/yabai/yabairc"           "$HOME/.yabairc"
create_symlink "$DOTFILES/skhd/skhdrc"             "$HOME/.config/skhd/skhdrc"
create_symlink "$DOTFILES/skhd/skhdrc"             "$HOME/.skhdrc"
create_symlink "$DOTFILES/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"

KARABINER_CLI="$(karabiner_cli_path || true)"
if [[ -n "$KARABINER_CLI" ]]; then
    if "$KARABINER_CLI" --select-profile cortex &>/dev/null; then
        echo "  ✓ Perfil Karabiner cortex seleccionado"
    else
        echo "  ! No se pudo seleccionar el perfil Karabiner cortex; abrí Karabiner-Elements para activarlo"
    fi
fi

# --- Servicios macOS ---
echo ""
echo "🚀 Asegurando servicios macOS..."

warn_service() {
    local name="$1"
    local command_hint="$2"
    echo "  ! No se pudo iniciar $name. macOS puede requerir permisos en Privacy & Security > Accessibility."
    echo "    Fallback manual: $command_hint"
}

if command -v brew &>/dev/null && command -v sketchybar &>/dev/null; then
    if brew services start sketchybar &>/dev/null; then
        echo "  ✓ sketchybar iniciado via brew services"
    else
        warn_service "sketchybar" "brew services start sketchybar"
    fi
else
    echo "  - sketchybar no disponible; se omite"
fi

if command -v yabai &>/dev/null; then
    if pgrep -x yabai &>/dev/null; then
        if yabai --restart-service &>/dev/null; then
            echo "  ✓ yabai reiniciado"
        else
            warn_service "yabai" "yabai --restart-service"
        fi
    elif yabai --start-service &>/dev/null; then
        echo "  ✓ yabai iniciado"
    else
        warn_service "yabai" "yabai --start-service"
    fi
else
    echo "  - yabai no disponible; se omite"
fi

if command -v skhd &>/dev/null; then
    if pgrep -x skhd &>/dev/null; then
        if skhd --reload &>/dev/null; then
            echo "  ✓ skhd recargado"
        else
            warn_service "skhd" "skhd --reload"
        fi
    elif skhd --start-service &>/dev/null; then
        echo "  ✓ skhd iniciado"
    else
        warn_service "skhd" "skhd --start-service"
    fi
else
    echo "  - skhd no disponible; se omite"
fi

# --- Copiar colorschemes de micro (no pueden ser symlink) ---
echo ""
echo "📝 Copiando colorschemes de micro..."
mkdir -p "$HOME/.config/micro/colorschemes"
cp -v "$DOTFILES/micro/colorschemes"/*.micro "$HOME/.config/micro/colorschemes/" || true
echo "  ✓ Colorschemes copiados"

# --- Configuración local ---
echo ""
if [[ ! -f "$DOTFILES/local/env.zsh" ]]; then
    cp "$DOTFILES/local/env.zsh.example" "$DOTFILES/local/env.zsh"
    echo "📝 Creado local/env.zsh desde el ejemplo — editalo con tus paths"
else
    echo "✓ local/env.zsh ya existe"
fi

# --- Verificación final ---
echo ""
echo "✅ Instalación completada!"
echo ""
echo "  Próximos pasos:"
echo "  1. Abrí una nueva tab en Ghostty para cargar el nuevo profile"
echo "  2. Editá local/env.zsh con tus paths personales"
echo "  3. Ghostty ya usa FiraCode Nerd Font Mono Beard (reiniciá si no se ve bien)"
echo "  4. Usá zj, cc u oc para abrir sesiones Zellij por repo"
echo "  5. Si macOS bloqueó servicios, habilitá Accessibility y corré los fallbacks impresos arriba"
echo "  6. Abrí Karabiner-Elements y habilitá Input Monitoring/Accessibility si macOS lo pide"
echo ""
echo "  Para medir el load time:"
echo "  \$ time zsh -i -c exit"
echo ""
