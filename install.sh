#!/bin/bash
# install.sh — Instalador de dotfiles macOS/Linux
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OS="$(uname -s)"
IS_MACOS=false
IS_LINUX=false

case "$OS" in
    Darwin) IS_MACOS=true ;;
    Linux) IS_LINUX=true ;;
    *)
        echo "❌ Sistema no soportado: $OS"
        exit 1
        ;;
esac

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║    dotfiles — Instalador macOS/Linux ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# --- Verificar herramientas ---
echo "📦 Verificando herramientas ($OS)..."

install_with_brew() {
    local command_name="$1"
    local package_name="$2"
    local description="$3"

    if command -v "$command_name" &>/dev/null; then
        echo "  ✓ $command_name ya instalado"
        return
    fi

    if $IS_MACOS; then
        if ! command -v brew &>/dev/null; then
            echo "❌ Homebrew no está instalado. Instalá desde https://brew.sh"
            exit 1
        fi

        echo "  → Instalando $description..."
        brew install "$package_name"
    else
        echo "  ! $command_name no está instalado; instalalo con el package manager de esta distro si lo necesitás"
    fi
}

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

install_with_brew starship starship "starship"
install_with_brew micro micro "micro (editor terminal)"
install_with_brew eza eza "eza (ls mejorado)"
install_with_brew herdr herdr "herdr (multiplexor remoto persistente)"
install_with_brew mosh mosh "mosh (SSH resiliente para workstations remotas)"
install_with_brew lazygit lazygit "lazygit (git TUI)"

if $IS_MACOS; then
    install_with_brew sketchybar sketchybar "sketchybar (barra macOS)"

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
fi

# --- Fuentes ---
echo ""
echo "📦 Verificando fuentes..."

if $IS_MACOS; then
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
else
    echo "  - Fuentes macOS omitidas en Linux"
fi

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
backup_if_exists "$HOME/.bunfig.toml"
backup_if_exists "$HOME/.config/uv/uv.toml"
backup_if_exists "$HOME/.config/starship.toml"
backup_if_exists "$HOME/.config/herdr/config.toml"
backup_if_exists "$HOME/.claude/statusline.sh"
backup_if_exists "$HOME/.config/lazygit/config.yml"

if $IS_MACOS; then
    backup_if_exists "$HOME/Library/Preferences/pnpm/rc"
    backup_if_exists "$HOME/.config/ghostty/config"
    backup_if_exists "$HOME/Library/Application Support/com.cmuxterm.app/config.ghostty"
    backup_if_exists "$HOME/.config/sketchybar"
    backup_if_exists "$HOME/.config/yabai/yabairc"
    backup_if_exists "$HOME/.yabairc"
    backup_if_exists "$HOME/.config/skhd/skhdrc"
    backup_if_exists "$HOME/.skhdrc"
    backup_karabiner_if_exists
else
    backup_if_exists "$HOME/.config/pnpm/rc"
fi

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
create_symlink "$DOTFILES/bun/bunfig.toml"         "$HOME/.bunfig.toml"
create_symlink "$DOTFILES/uv/uv.toml"              "$HOME/.config/uv/uv.toml"
create_symlink "$DOTFILES/starship/starship.toml"  "$HOME/.config/starship.toml"
create_symlink "$DOTFILES/herdr/config.toml"       "$HOME/.config/herdr/config.toml"
chmod +x "$DOTFILES/claude/statusline.sh"
create_symlink "$DOTFILES/claude/statusline.sh"    "$HOME/.claude/statusline.sh"
create_symlink "$DOTFILES/micro/settings.json"     "$HOME/.config/micro/settings.json"
create_symlink "$DOTFILES/lazygit/config.yml"      "$HOME/.config/lazygit/config.yml"

if $IS_MACOS; then
    create_symlink "$DOTFILES/pnpm/rc"                 "$HOME/Library/Preferences/pnpm/rc"
    create_symlink "$DOTFILES/ghostty/config"          "$HOME/.config/ghostty/config"
    create_symlink "$DOTFILES/ghostty/cmux.conf"       "$HOME/Library/Application Support/com.cmuxterm.app/config.ghostty"
    create_symlink "$DOTFILES/ghostty/shaders"         "$HOME/.config/ghostty/shaders"
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
else
    create_symlink "$DOTFILES/pnpm/rc"                 "$HOME/.config/pnpm/rc"
fi

if $IS_MACOS; then
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
else
    echo ""
    echo "🚀 Servicios macOS omitidos en Linux"
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
echo "  1. Abrí una nueva shell para cargar el nuevo profile"
echo "  2. Editá local/env.zsh con tus paths personales"
if $IS_MACOS; then
    echo "  3. Ghostty ya usa FiraCode Nerd Font Mono Beard (reiniciá si no se ve bien)"
    echo "  4. Usá hhere, hremote, cc u oc para trabajar dentro de Herdr"
    echo "  5. Si macOS bloqueó servicios, habilitá Accessibility y corré los fallbacks impresos arriba"
    echo "  6. Abrí Karabiner-Elements y habilitá Input Monitoring/Accessibility si macOS lo pide"
else
    echo "  3. Instalá manualmente herramientas faltantes que el script haya marcado con !"
    echo "  4. Usá hhere, hremote, cc u oc para trabajar dentro de Herdr"
fi
echo ""
echo "  Para medir el load time:"
echo "  \$ time zsh -i -c exit"
echo ""
