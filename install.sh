#!/bin/bash
# install.sh — Instalador de dotfiles macOS
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [[ "${1:-}" == "--check" ]]; then
    WARNINGS=0
    CRITICAL_FAILURES=0

    pass() {
        printf 'PASS %s\n' "$1"
    }

    warn() {
        printf 'WARN %s\n' "$1"
        WARNINGS=$((WARNINGS + 1))
    }

    fail() {
        printf 'FAIL %s\n' "$1"
        CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
    }

    rel_path() {
        local path="$1"
        printf '%s\n' "${path#"$DOTFILES"/}"
    }

    check_command() {
        local command_name="$1"
        local severity="${2:-warn}"

        if command -v "$command_name" &>/dev/null; then
            pass "tool available: $command_name"
        elif [[ "$severity" == "fail" ]]; then
            fail "missing required tool: $command_name"
        else
            warn "missing optional tool: $command_name"
        fi
    }

    check_file() {
        local path="$1"
        if [[ -e "$path" ]]; then
            pass "repo file exists: $(rel_path "$path")"
        else
            fail "missing repo file: $(rel_path "$path")"
        fi
    }

    check_symlink_target() {
        local src="$1"
        local dst="$2"

        check_file "$src"

        if [[ -L "$dst" ]]; then
            local current
            current="$(readlink "$dst")"
            if [[ "$current" == "$src" ]]; then
                pass "symlink ok: $dst -> $src"
            else
                warn "symlink points elsewhere: $dst -> $current (expected $src)"
            fi
        elif [[ -e "$dst" ]]; then
            warn "existing non-symlink would be backed up by install: $dst"
        else
            warn "dotfile target not installed yet: $dst"
        fi
    }

    check_json() {
        local path="$1"
        [[ -f "$path" ]] || return 0

        if command -v python3 &>/dev/null; then
            if python3 -m json.tool "$path" >/dev/null; then
                pass "JSON syntax ok: $(rel_path "$path")"
            else
                fail "JSON syntax invalid: $(rel_path "$path")"
            fi
        else
            warn "python3 unavailable; skipped JSON syntax: $(rel_path "$path")"
        fi
    }

    check_toml() {
        local path="$1"
        [[ -f "$path" ]] || return 0

        if command -v python3 &>/dev/null; then
            if python3 - "$path" <<'PY'
import sys
try:
    import tomllib
except ModuleNotFoundError:
    sys.exit(2)
with open(sys.argv[1], 'rb') as fh:
    tomllib.load(fh)
PY
            then
                pass "TOML syntax ok: $(rel_path "$path")"
            else
                local status=$?
                if [[ "$status" -eq 2 ]]; then
                    warn "python3 tomllib unavailable; skipped TOML syntax: $(rel_path "$path")"
                else
                    fail "TOML syntax invalid: $(rel_path "$path")"
                fi
            fi
        else
            warn "python3 unavailable; skipped TOML syntax: $(rel_path "$path")"
        fi
    }

    check_shell() {
        local path="$1"
        local shell_name="$2"
        [[ -f "$path" ]] || return 0

        if command -v "$shell_name" &>/dev/null; then
            if "$shell_name" -n "$path"; then
                pass "$shell_name syntax ok: $(rel_path "$path")"
            else
                fail "$shell_name syntax invalid: $(rel_path "$path")"
            fi
        else
            warn "$shell_name unavailable; skipped shell syntax: $(rel_path "$path")"
        fi
    }

    check_karabiner_app_exists() {
        [[ -d "/Applications/Karabiner-Elements.app" || -d "$HOME/Applications/Karabiner-Elements.app" ]]
    }

    check_karabiner_cli_available() {
        command -v karabiner_cli &>/dev/null || [[ -x "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli" ]]
    }

    echo "dotfiles install check"
    echo "repo: $DOTFILES"
    echo ""

    case "$(uname -s)" in
        Darwin)
            pass "platform supported: macOS"
            check_command brew fail
            check_command zsh fail
            check_command bash fail
            check_command starship warn
            check_command micro warn
            check_command eza warn
            check_command tmux warn
            check_command lazygit warn
            check_command sketchybar warn
            check_command yabai warn
            check_command skhd warn
            if check_karabiner_cli_available || check_karabiner_app_exists; then
                pass "Karabiner-Elements available"
            else
                warn "Karabiner-Elements unavailable"
            fi
            ;;
        Linux)
            warn "platform is Linux; installer is macOS-focused, so Homebrew/macOS services are not required for this check"
            check_command bash fail
            check_command zsh warn
            check_command python3 warn
            ;;
        *)
            warn "unsupported platform: $(uname -s)"
            check_command bash fail
            check_command zsh warn
            check_command python3 warn
            ;;
    esac

    echo ""
    echo "checking fonts"
    check_file "$DOTFILES/fonts/FiraCodeNerdFontMonoBeard-Reg.ttf"
    if [[ -f "$HOME/Library/Fonts/FiraCodeNerdFontMonoBeard-Reg.ttf" ]]; then
        pass "font installed: FiraCode Nerd Font Mono Beard"
    elif compgen -G "$HOME/Library/Fonts/FiraCodeNerdFont*" >/dev/null; then
        warn "FiraCode Nerd Font present, custom Beard font not installed"
    else
        warn "FiraCode Nerd Font not found in ~/Library/Fonts"
    fi

    echo ""
    echo "checking symlink targets"
    check_symlink_target "$DOTFILES/zsh/zshrc" "$HOME/.zshrc"
    check_symlink_target "$DOTFILES/npm/npmrc" "$HOME/.npmrc"
    check_symlink_target "$DOTFILES/pnpm/rc" "$HOME/Library/Preferences/pnpm/rc"
    check_symlink_target "$DOTFILES/bun/bunfig.toml" "$HOME/.bunfig.toml"
    check_symlink_target "$DOTFILES/uv/uv.toml" "$HOME/.config/uv/uv.toml"
    check_symlink_target "$DOTFILES/starship/starship.toml" "$HOME/.config/starship.toml"
    check_symlink_target "$DOTFILES/ghostty/config" "$HOME/.config/ghostty/config"
    check_symlink_target "$DOTFILES/ghostty/cmux.conf" "$HOME/Library/Application Support/com.cmuxterm.app/config.ghostty"
    check_symlink_target "$DOTFILES/ghostty/shaders" "$HOME/.config/ghostty/shaders"
    check_symlink_target "$DOTFILES/tmux/tmux.conf" "$HOME/.tmux.conf"
    check_symlink_target "$DOTFILES/claude/statusline.sh" "$HOME/.claude/statusline.sh"
    check_symlink_target "$DOTFILES/micro/settings.json" "$HOME/.config/micro/settings.json"
    check_symlink_target "$DOTFILES/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
    check_symlink_target "$DOTFILES/sketchybar" "$HOME/.config/sketchybar"
    check_symlink_target "$DOTFILES/yabai/yabairc" "$HOME/.config/yabai/yabairc"
    check_symlink_target "$DOTFILES/yabai/yabairc" "$HOME/.yabairc"
    check_symlink_target "$DOTFILES/skhd/skhdrc" "$HOME/.config/skhd/skhdrc"
    check_symlink_target "$DOTFILES/skhd/skhdrc" "$HOME/.skhdrc"
    check_symlink_target "$DOTFILES/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"

    echo ""
    echo "checking syntax"
    check_shell "$DOTFILES/install.sh" bash
    check_shell "$DOTFILES/claude/statusline.sh" bash
    for path in "$DOTFILES"/sketchybar/sketchybarrc "$DOTFILES"/sketchybar/sketchybar-profile.sh "$DOTFILES"/sketchybar/plugins/*.sh; do
        check_shell "$path" bash
    done
    check_shell "$DOTFILES/zsh/zshrc" zsh
    for path in "$DOTFILES"/zsh/scripts/*.zsh; do
        check_shell "$path" zsh
    done
    check_json "$DOTFILES/karabiner/karabiner.json"
    check_json "$DOTFILES/micro/settings.json"
    for path in "$DOTFILES"/opencode/*.json "$DOTFILES"/opencode/**/*.json "$DOTFILES"/claude/themes/*.json; do
        check_json "$path"
    done
    check_toml "$DOTFILES/starship/starship.toml"
    check_toml "$DOTFILES/bun/bunfig.toml"
    check_toml "$DOTFILES/uv/uv.toml"
    for path in "$DOTFILES"/herdr/*.toml "$DOTFILES"/herdr/**/*.toml; do
        check_toml "$path"
    done

    echo ""
    if [[ "$CRITICAL_FAILURES" -gt 0 ]]; then
        echo "FAIL check completed with $CRITICAL_FAILURES critical failure(s) and $WARNINGS warning(s)"
        exit 1
    fi

    echo "PASS check completed with $WARNINGS warning(s)"
    exit 0
fi

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

if ! command -v tmux &>/dev/null; then
    echo "  → Instalando tmux (multiplexor de terminal)..."
    brew install tmux
else
    echo "  ✓ tmux ya instalado"
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
backup_if_exists "$HOME/Library/Application Support/com.cmuxterm.app/config.ghostty"
backup_if_exists "$HOME/.tmux.conf"
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
create_symlink "$DOTFILES/ghostty/cmux.conf"       "$HOME/Library/Application Support/com.cmuxterm.app/config.ghostty"
create_symlink "$DOTFILES/ghostty/shaders"         "$HOME/.config/ghostty/shaders"
create_symlink "$DOTFILES/tmux/tmux.conf"          "$HOME/.tmux.conf"
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
echo "  4. Si macOS bloqueó servicios, habilitá Accessibility y corré los fallbacks impresos arriba"
echo "  5. Abrí Karabiner-Elements y habilitá Input Monitoring/Accessibility si macOS lo pide"
echo ""
echo "  Para medir el load time:"
echo "  \$ time zsh -i -c exit"
echo ""
