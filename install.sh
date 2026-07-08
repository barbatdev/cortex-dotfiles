#!/bin/bash
# install.sh — Instalador de dotfiles macOS/Linux
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DRY_RUN=false
PLATFORM="$(uname -s)"

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

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
            check_command nvim warn
            check_command eza warn
            check_command herdr warn
            check_command mosh warn
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
            pass "platform supported: Linux"
            check_command bash fail
            check_command zsh warn
            check_command python3 warn
            check_command starship warn
            check_command nvim warn
            check_command herdr warn
            check_command mosh warn
            check_command tmux warn
            check_command lazygit warn
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
    if [[ "$(uname -s)" != "Darwin" ]]; then
        pass "font install check skipped on non-macOS platform"
    elif [[ -f "$HOME/Library/Fonts/FiraCodeNerdFontMonoBeard-Reg.ttf" ]]; then
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
    check_symlink_target "$DOTFILES/bun/bunfig.toml" "$HOME/.bunfig.toml"
    check_symlink_target "$DOTFILES/uv/uv.toml" "$HOME/.config/uv/uv.toml"
    check_symlink_target "$DOTFILES/starship/starship.toml" "$HOME/.config/starship.toml"
    check_symlink_target "$DOTFILES/herdr/config.toml" "$HOME/.config/herdr/config.toml"
    check_symlink_target "$DOTFILES/ghostty/config" "$HOME/.config/ghostty/config"
    check_symlink_target "$DOTFILES/ghostty/shaders" "$HOME/.config/ghostty/shaders"
    check_symlink_target "$DOTFILES/opencode/tui.json" "$HOME/.config/opencode/tui.json"
    check_symlink_target "$DOTFILES/opencode/themes" "$HOME/.config/opencode/themes"
    check_symlink_target "$DOTFILES/tmux/tmux.conf" "$HOME/.tmux.conf"
    check_symlink_target "$DOTFILES/claude/statusline.sh" "$HOME/.claude/statusline.sh"
    check_symlink_target "$DOTFILES/claude/themes" "$HOME/.claude/themes"
    check_symlink_target "$DOTFILES/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        check_symlink_target "$DOTFILES/pnpm/rc" "$HOME/Library/Preferences/pnpm/rc"
        check_symlink_target "$DOTFILES/sketchybar" "$HOME/.config/sketchybar"
        check_symlink_target "$DOTFILES/yabai/yabairc" "$HOME/.config/yabai/yabairc"
        check_symlink_target "$DOTFILES/yabai/yabairc" "$HOME/.yabairc"
        check_symlink_target "$DOTFILES/skhd/skhdrc" "$HOME/.config/skhd/skhdrc"
        check_symlink_target "$DOTFILES/skhd/skhdrc" "$HOME/.skhdrc"
        check_symlink_target "$DOTFILES/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
    else
        pass "macOS-only symlink targets skipped on non-macOS platform"
    fi

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

if [[ "${1:-}" != "" && "${1:-}" != "--dry-run" ]]; then
    echo "Usage: $0 [--check|--dry-run]"
    exit 1
fi

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║    dotfiles — Instalador macOS/Linux ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo "DRY RUN: no files, packages, services, symlinks, chmods, or local config will be changed."
    echo ""
fi

run_or_plan() {
    local message="$1"
    shift

    if [[ "$DRY_RUN" == true ]]; then
        echo "  → Would $message"
    else
        "$@"
    fi
}

install_formula_if_missing() {
    local command_name="$1"
    local formula="$2"
    local description="$3"
    local tap="${4:-}"

    if ! command -v "$command_name" &>/dev/null; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "  → Would install $formula ($description) via Homebrew"
        else
            echo "  → Instalando $formula ($description)..."
            [[ -z "$tap" ]] || brew tap "$tap"
            brew install "$formula"
        fi
    else
        echo "  ✓ $command_name ya instalado"
    fi
}

# --- Verificar dependencias base ---
echo "📦 Verificando herramientas ($PLATFORM)..."

if [[ "$PLATFORM" == "Darwin" ]]; then
    if ! command -v brew &>/dev/null; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "  → Would require Homebrew before installing packages"
        else
            echo "❌ Homebrew no está instalado. Instalá desde https://brew.sh"
            exit 1
        fi
    fi

    install_formula_if_missing starship starship "prompt"
elif [[ "$PLATFORM" == "Linux" ]]; then
    for tool in zsh starship nvim herdr mosh tmux lazygit; do
        if command -v "$tool" &>/dev/null; then
            echo "  ✓ $tool ya instalado"
        else
            echo "  ! $tool no encontrado; instalalo con el package manager del sistema si lo necesitás"
        fi
    done
else
    echo "❌ Plataforma no soportada: $PLATFORM"
    exit 1
fi

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

if [[ "$PLATFORM" == "Darwin" ]]; then
    install_formula_if_missing nvim neovim "editor terminal"
    install_formula_if_missing eza eza "ls mejorado"
    install_formula_if_missing herdr herdr "multiplexor remoto persistente"
    install_formula_if_missing mosh mosh "SSH resiliente para workstations remotas"
    install_formula_if_missing tmux tmux "multiplexor de terminal"
    install_formula_if_missing lazygit lazygit "git TUI"
    install_formula_if_missing sketchybar sketchybar "barra macOS"
    install_formula_if_missing yabai yabai "window manager macOS" koekeishiya/formulae
    install_formula_if_missing skhd skhd "hotkeys macOS" koekeishiya/formulae

    if ! karabiner_cli_available && ! karabiner_app_exists; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "  → Would install karabiner-elements via Homebrew cask"
        else
            echo "  → Instalando Karabiner-Elements..."
            brew install --cask karabiner-elements
        fi
    else
        echo "  ✓ Karabiner-Elements ya instalado"
    fi
fi

# --- Fuentes ---
echo ""
echo "📦 Verificando fuentes..."

if [[ "$PLATFORM" != "Darwin" ]]; then
    echo "  - fuentes macOS omitidas en Linux"
elif ! ls "$HOME/Library/Fonts/FiraCodeNerdFont"* &>/dev/null 2>&1; then
    if [[ "$DRY_RUN" == true ]]; then
        echo "  → Would install font-fira-code-nerd-font via Homebrew cask"
    else
        echo "  → Instalando FiraCode Nerd Font..."
        brew install --cask font-fira-code-nerd-font
        echo "  ✓ FiraCode Nerd Font instalada"
    fi
else
    echo "  ✓ FiraCode Nerd Font ya instalada"
fi

if [[ "$PLATFORM" != "Darwin" ]]; then
    :
elif [[ "$DRY_RUN" == true ]]; then
    echo "  → Would create $HOME/Library/Fonts"
    echo "  → Would copy $DOTFILES/fonts/FiraCodeNerdFontMonoBeard-Reg.ttf to $HOME/Library/Fonts/FiraCodeNerdFontMonoBeard-Reg.ttf"
else
    mkdir -p "$HOME/Library/Fonts"
    cp "$DOTFILES/fonts/FiraCodeNerdFontMonoBeard-Reg.ttf" "$HOME/Library/Fonts/FiraCodeNerdFontMonoBeard-Reg.ttf"
    echo "  ✓ FiraCode Nerd Font Mono Beard instalada"
fi

# --- Backup de configs existentes ---
echo ""
echo "💾 Haciendo backup de configs existentes..."

backup_if_exists() {
    local src="$1"
    if [[ -e "$src" || -L "$src" ]]; then
        local backup="${src}.bak_${TIMESTAMP}"
        if [[ "$DRY_RUN" == true ]]; then
            echo "  → Would backup $src to $backup"
        else
            mv "$src" "$backup"
            echo "  → Backup: $backup"
        fi
    fi
}

backup_karabiner_if_exists() {
    local src="$HOME/.config/karabiner/karabiner.json"
    if [[ -e "$src" || -L "$src" ]]; then
        local backup="${src}.bak_${TIMESTAMP}"
        if [[ "$DRY_RUN" == true ]]; then
            echo "  → Would backup $src to $backup"
        else
            if [[ -L "$src" ]]; then
                cp -P "$src" "$backup"
            else
                cp "$src" "$backup"
            fi
            echo "  → Backup: $backup"
        fi
    fi
}

backup_if_exists "$HOME/.zshrc"
backup_if_exists "$HOME/.npmrc"
backup_if_exists "$HOME/.bunfig.toml"
backup_if_exists "$HOME/.config/uv/uv.toml"
backup_if_exists "$HOME/.config/starship.toml"
backup_if_exists "$HOME/.config/herdr/config.toml"
backup_if_exists "$HOME/.config/ghostty/config"
backup_if_exists "$HOME/.config/opencode/tui.json"
backup_if_exists "$HOME/.config/opencode/themes"
backup_if_exists "$HOME/.tmux.conf"
backup_if_exists "$HOME/.claude/statusline.sh"
backup_if_exists "$HOME/.claude/themes"
backup_if_exists "$HOME/.config/lazygit/config.yml"
if [[ "$PLATFORM" == "Darwin" ]]; then
    backup_if_exists "$HOME/Library/Preferences/pnpm/rc"
    backup_if_exists "$HOME/.config/sketchybar"
    backup_if_exists "$HOME/.config/yabai/yabairc"
    backup_if_exists "$HOME/.yabairc"
    backup_if_exists "$HOME/.config/skhd/skhdrc"
    backup_if_exists "$HOME/.skhdrc"
    backup_karabiner_if_exists
fi

# --- Crear symlinks ---
echo ""
echo "🔗 Creando symlinks..."

create_symlink() {
    local src="$1"
    local dst="$2"
    if [[ "$DRY_RUN" == true ]]; then
        echo "  → Would symlink $dst → $src"
    else
        mkdir -p "$(dirname "$dst")"
        # -n evita que ln dereferencie un symlink-a-directorio existente y cree
        # un link adentro (caso ghostty/shaders → loop shaders/shaders)
        ln -sfn "$src" "$dst"
        echo "  ✓ $dst → $src"
    fi
}

create_symlink "$DOTFILES/zsh/zshrc"              "$HOME/.zshrc"
create_symlink "$DOTFILES/npm/npmrc"               "$HOME/.npmrc"
create_symlink "$DOTFILES/bun/bunfig.toml"         "$HOME/.bunfig.toml"
create_symlink "$DOTFILES/uv/uv.toml"              "$HOME/.config/uv/uv.toml"
create_symlink "$DOTFILES/starship/starship.toml"  "$HOME/.config/starship.toml"
create_symlink "$DOTFILES/herdr/config.toml"       "$HOME/.config/herdr/config.toml"
create_symlink "$DOTFILES/ghostty/config"          "$HOME/.config/ghostty/config"
create_symlink "$DOTFILES/ghostty/shaders"         "$HOME/.config/ghostty/shaders"
create_symlink "$DOTFILES/opencode/tui.json"       "$HOME/.config/opencode/tui.json"
create_symlink "$DOTFILES/opencode/themes"         "$HOME/.config/opencode/themes"
create_symlink "$DOTFILES/tmux/tmux.conf"          "$HOME/.tmux.conf"
run_or_plan "chmod +x $DOTFILES/claude/statusline.sh" chmod +x "$DOTFILES/claude/statusline.sh"
create_symlink "$DOTFILES/claude/statusline.sh"    "$HOME/.claude/statusline.sh"
create_symlink "$DOTFILES/claude/themes"           "$HOME/.claude/themes"
create_symlink "$DOTFILES/lazygit/config.yml"      "$HOME/.config/lazygit/config.yml"
if [[ "$PLATFORM" == "Darwin" ]]; then
    create_symlink "$DOTFILES/pnpm/rc"                 "$HOME/Library/Preferences/pnpm/rc"
    run_or_plan "chmod +x sketchybar scripts" chmod +x "$DOTFILES/sketchybar/sketchybarrc" "$DOTFILES/sketchybar/plugins"/*.sh
    create_symlink "$DOTFILES/sketchybar"              "$HOME/.config/sketchybar"
    run_or_plan "chmod +x $DOTFILES/yabai/yabairc" chmod +x "$DOTFILES/yabai/yabairc"
    create_symlink "$DOTFILES/yabai/yabairc"           "$HOME/.config/yabai/yabairc"
    create_symlink "$DOTFILES/yabai/yabairc"           "$HOME/.yabairc"
    create_symlink "$DOTFILES/skhd/skhdrc"             "$HOME/.config/skhd/skhdrc"
    create_symlink "$DOTFILES/skhd/skhdrc"             "$HOME/.skhdrc"
    create_symlink "$DOTFILES/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"

    KARABINER_CLI="$(karabiner_cli_path || true)"
    if [[ -n "$KARABINER_CLI" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "  → Would select Karabiner profile cortex with $KARABINER_CLI"
        elif "$KARABINER_CLI" --select-profile cortex &>/dev/null; then
            echo "  ✓ Perfil Karabiner cortex seleccionado"
        else
            echo "  ! No se pudo seleccionar el perfil Karabiner cortex; abrí Karabiner-Elements para activarlo"
        fi
    elif [[ "$DRY_RUN" == true ]]; then
        echo "  → Would select Karabiner profile cortex if karabiner_cli is available after install"
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

if [[ "$PLATFORM" != "Darwin" ]]; then
    echo "  - servicios macOS omitidos en $PLATFORM"
elif [[ "$DRY_RUN" == true ]]; then
    echo "  → Would start sketchybar via brew services and reload if available"
elif command -v brew &>/dev/null && command -v sketchybar &>/dev/null; then
    if brew services start sketchybar &>/dev/null; then
        echo "  ✓ sketchybar iniciado via brew services"
        if sketchybar --reload &>/dev/null; then
            echo "  ✓ sketchybar recargado"
        else
            warn_service "sketchybar" "sketchybar --reload"
        fi
    else
        warn_service "sketchybar" "brew services start sketchybar"
    fi
else
    echo "  - sketchybar no disponible; se omite"
fi

if [[ "$PLATFORM" != "Darwin" ]]; then
    :
elif [[ "$DRY_RUN" == true ]]; then
    echo "  → Would start or restart yabai service if available"
elif command -v yabai &>/dev/null; then
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

if [[ "$PLATFORM" != "Darwin" ]]; then
    :
elif [[ "$DRY_RUN" == true ]]; then
    echo "  → Would start or reload skhd service if available"
elif command -v skhd &>/dev/null; then
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

# --- Configuración local ---
echo ""
if [[ ! -f "$DOTFILES/local/env.zsh" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo "📝 Would create local/env.zsh from local/env.zsh.example"
    else
        cp "$DOTFILES/local/env.zsh.example" "$DOTFILES/local/env.zsh"
        echo "📝 Creado local/env.zsh desde el ejemplo — editalo con tus paths"
    fi
else
    echo "✓ local/env.zsh ya existe"
fi

# --- Verificación final ---
echo ""
if [[ "$DRY_RUN" == true ]]; then
    echo "✅ Dry run completado; no se aplicaron cambios."
else
    echo "✅ Instalación completada!"
fi
echo ""
echo "  Próximos pasos:"
echo "  1. Abrí una nueva terminal para cargar el nuevo profile"
echo "  2. Editá local/env.zsh con tus paths personales"
if [[ "$PLATFORM" == "Darwin" ]]; then
    echo "  3. Ghostty ya usa FiraCode Nerd Font Mono Beard (reiniciá si no se ve bien)"
    echo "  4. Si macOS bloqueó servicios, habilitá Accessibility y corré los fallbacks impresos arriba"
    echo "  5. Abrí Karabiner-Elements y habilitá Input Monitoring/Accessibility si macOS lo pide"
else
    echo "  3. Instalá zsh/starship/neovim/herdr/mosh/tmux/lazygit con el package manager del sistema si faltan"
fi
echo ""
echo "  Para medir el load time:"
echo "  \$ time zsh -i -c exit"
echo ""
