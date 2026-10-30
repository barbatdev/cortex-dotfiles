#!/bin/bash
# install.sh — Instalador de dotfiles macOS/Linux
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DRY_RUN=false
PLATFORM="$(uname -s)"

# --- Managed symlink manifest (single source of truth) ---
# Format: "repo-relative-src|absolute-destination|platform"
# platform: "all" or "darwin". Consumed by backup, symlink creation and --check,
# so a new dotfile only needs one entry here.
MANAGED_LINKS=(
  "zsh/zshrc|$HOME/.zshrc|all"
  "npm/npmrc|$HOME/.npmrc|all"
  "bun/bunfig.toml|$HOME/.bunfig.toml|all"
  "aerospace/aerospace.toml|$HOME/.config/aerospace/aerospace.toml|all"
  "yabai/yabairc|$HOME/.yabairc|darwin"
  "uv/uv.toml|$HOME/.config/uv/uv.toml|all"
  "starship/starship.toml|$HOME/.config/starship.toml|all"
  "herdr/config.toml|$HOME/.config/herdr/config.toml|all"
  "herdr/config-base.toml|$HOME/.config/herdr/config-base.toml|all"
  "herdr/profiles/barbatdev.toml|$HOME/.config/herdr/profiles/barbatdev.toml|all"
  "herdr/profiles/refactoria.toml|$HOME/.config/herdr/profiles/refactoria.toml|all"
  "fish/themes/barbatdev.fish|$HOME/.config/fish/themes/barbatdev.fish|all"
  "fish/themes/refactoria.fish|$HOME/.config/fish/themes/refactoria.fish|all"
  "fish/functions/hbarbatdev.fish|$HOME/.config/fish/functions/hbarbatdev.fish|all"
  "fish/functions/hrefactoria.fish|$HOME/.config/fish/functions/hrefactoria.fish|all"
  "fish/functions/__herdr_tab_autoname.fish|$HOME/.config/fish/functions/__herdr_tab_autoname.fish|all"
  "pi/themes/barbatdev.json|$HOME/.pi/agent/themes/barbatdev.json|all"
  "pi/themes/refactoria.json|$HOME/.pi/agent/themes/refactoria.json|all"
  "ghostty/config|$HOME/.config/ghostty/config|all"
  "herdr/desktop/themes/refactoria.json|$HOME/.config/herdr-app/themes/refactoria.json|darwin"
  "ghostty/shaders|$HOME/.config/ghostty/shaders|all"
  "ghostty/profiles/barbatdev.conf|$HOME/.config/ghostty/profiles/barbatdev.conf|darwin"
  "ghostty/profiles/refactoria.conf|$HOME/.config/ghostty/profiles/refactoria.conf|darwin"
  "fish/functions/gbarbatdev.fish|$HOME/.config/fish/functions/gbarbatdev.fish|darwin"
  "fish/functions/grefactoria.fish|$HOME/.config/fish/functions/grefactoria.fish|darwin"
  "opencode/themes|$HOME/.config/opencode/themes|all"
  "tmux/tmux.conf|$HOME/.tmux.conf|all"
  "claude/statusline.sh|$HOME/.claude/statusline.sh|all"
  "claude/themes|$HOME/.claude/themes|all"
  "lazygit/config.yml|$HOME/.config/lazygit/config.yml|all"
  "pnpm/rc|$HOME/Library/Preferences/pnpm/rc|darwin"
  "sketchybar|$HOME/.config/sketchybar|darwin"
  "karabiner/karabiner.json|$HOME/.config/karabiner/karabiner.json|darwin"
  "pi/extensions/cortex-agent-state.ts|$HOME/.pi/agent/extensions/cortex-agent-state.ts|all"
  "zsh/scripts/agent-state.sh|$HOME/.local/bin/agent-state|all"
)

# Whether a manifest entry (src|dst|platform) applies to the current platform.
link_applies() {
    local platform="$3"
    [[ "$platform" == "all" ]] && return 0
    [[ "$platform" == "darwin" && "$PLATFORM" == "Darwin" ]]
}

# Emit each applicable manifest entry as "abs-src|dst|platform".
manifest_entries() {
    local entry src dst platform
    for entry in "${MANAGED_LINKS[@]}"; do
        IFS='|' read -r src dst platform <<<"$entry"
        link_applies "$src" "$dst" "$platform" || continue
        printf '%s|%s|%s\n' "$DOTFILES/$src" "$dst" "$platform"
    done
}

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
            check_command tmux warn
            check_command lazygit warn
            check_command sketchybar warn
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
    manifest_count=0
    while IFS='|' read -r src dst _; do
        check_symlink_target "$src" "$dst"
        manifest_count=$((manifest_count + 1))
    done < <(manifest_entries)
    pass "manifest symlinks checked: $manifest_count"
    check_file "$DOTFILES/opencode/tui.json"
    if [[ -L "$HOME/.config/opencode/tui.json" ]]; then
        warn "opencode tui.json is a symlink; gentle-ai sync refuses it (install.sh converts it to a copy)"
    fi
    if [[ "$(uname -s)" != "Darwin" ]]; then
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
    for path in "$DOTFILES"/zsh/scripts/*.sh; do
        check_shell "$path" bash
    done
    check_json "$DOTFILES/karabiner/karabiner.json"
    while IFS= read -r -d '' path; do
        check_json "$path"
    done < <(find "$DOTFILES/opencode" "$DOTFILES/claude/themes" "$DOTFILES/pi/themes" -name '*.json' -type f -print0 2>/dev/null | sort -z)
    for path in \
        "$DOTFILES/fish/themes/barbatdev.fish" \
        "$DOTFILES/fish/themes/refactoria.fish" \
        "$DOTFILES/fish/functions/hbarbatdev.fish" \
        "$DOTFILES/fish/functions/hrefactoria.fish" \
        "$DOTFILES/fish/functions/__herdr_tab_autoname.fish" \
        "$DOTFILES/fish/functions/gbarbatdev.fish" \
        "$DOTFILES/fish/functions/grefactoria.fish"; do
        check_shell "$path" fish
    done
    check_toml "$DOTFILES/starship/starship.toml"
    check_toml "$DOTFILES/bun/bunfig.toml"
    check_toml "$DOTFILES/uv/uv.toml"
    while IFS= read -r -d '' path; do
        check_toml "$path"
    done < <(find "$DOTFILES/herdr" -name '*.toml' -type f -print0 2>/dev/null | sort -z)

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

install_cask_if_missing() {
    local app_path="$1"
    local cask="$2"
    local tap="$3"

    if [[ -d "$app_path" ]]; then
        echo "  ✓ $cask ya instalado"
    elif [[ "$DRY_RUN" == true ]]; then
        echo "  → Would install $cask via Homebrew cask"
    else
        brew tap "$tap"
        brew install --cask "$cask"
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
    for tool in zsh starship nvim tmux lazygit; do
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
    install_formula_if_missing tmux tmux "multiplexor de terminal"
    install_formula_if_missing lazygit lazygit "git TUI"
    install_formula_if_missing sketchybar sketchybar "barra macOS"
    install_cask_if_missing "/Applications/AeroSpace.app" aerospace nikitabobko/tap

    # Inter: the RefactorIA UI sans, used by Herdr Desktop panels (ui_font).
    if ls "$HOME/Library/Fonts"/Inter-Regular.* &>/dev/null; then
        echo "  ✓ font-inter ya instalado"
    elif [[ "$DRY_RUN" == true ]]; then
        echo "  → Would install font-inter via Homebrew cask"
    else
        brew install --cask font-inter
    fi

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

# Unified backup: symlinks are backed up with cp -P (never following the
# operand into the repo), real files/dirs with cp -R. An already-correct
# managed symlink is skipped so re-running install creates no new backups.
backup_path() {
    local src="$1"
    local dst="$2"
    [[ -e "$dst" || -L "$dst" ]] || return 0
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        return 0
    fi
    local backup="${dst}.bak_${TIMESTAMP}"
    if [[ "$DRY_RUN" == true ]]; then
        echo "  → Would backup $dst to $backup"
    elif [[ -L "$dst" ]]; then
        cp -P "$dst" "$backup"
        echo "  → Backup: $backup"
    else
        cp -R "$dst" "$backup"
        echo "  → Backup: $backup"
    fi
}

# Pre-flight: a real directory at a symlink destination cannot be replaced by
# ln -sfn (it would fail mid-run with set -e). Abort cleanly before any change.
preflight_conflicts() {
    local src dst conflicts=0
    while IFS='|' read -r src dst _; do
        if [[ -d "$dst" && ! -L "$dst" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                echo "  → Would abort: $dst is a real directory; remove or move it before installing"
            else
                echo "❌ $dst es un directorio real; movelo o borralo antes de instalar (el symlink no puede reemplazarlo)."
            fi
            conflicts=$((conflicts + 1))
        fi
    done < <(manifest_entries)
    if [[ "$conflicts" -gt 0 && "$DRY_RUN" != true ]]; then
        echo "Abortando: $conflicts destino(s) son directorios reales y romperían la creación de symlinks."
        exit 1
    fi
}

preflight_conflicts

while IFS='|' read -r src dst _; do
    backup_path "$src" "$dst"
done < <(manifest_entries)

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

while IFS='|' read -r src dst _; do
    create_symlink "$src" "$dst"
done < <(manifest_entries)
# gentle-ai sync edits tui.json and refuses symlinks: seed a copy instead.
# shellcheck source=scripts/seed-file.sh
source "$DOTFILES/scripts/seed-file.sh"
seed_file "$DOTFILES/opencode/tui.json" "$HOME/.config/opencode/tui.json"
# Herdr Desktop rewrites settings.json (theme picker, zoom keys): seed a copy.
if [[ "$PLATFORM" == "Darwin" ]]; then
    seed_file "$DOTFILES/herdr/desktop/settings.json" "$HOME/.config/herdr-app/settings.json"
fi
run_or_plan "chmod +x $DOTFILES/claude/statusline.sh" chmod +x "$DOTFILES/claude/statusline.sh"
run_or_plan "chmod +x agent-state CLI" chmod +x "$DOTFILES/zsh/scripts/agent-state.sh"
if [[ "$PLATFORM" == "Darwin" ]]; then
    run_or_plan "chmod +x sketchybar scripts" chmod +x "$DOTFILES/sketchybar/sketchybarrc" "$DOTFILES/sketchybar/plugins"/*.sh

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

# --- Apariencia macOS ---
echo ""
echo "🎨 Apariencia macOS"
if [[ "$DRY_RUN" == true ]]; then
    "$DOTFILES/scripts/macos-appearance.sh" --dry-run
else
    "$DOTFILES/scripts/macos-appearance.sh"
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
    echo "  3. Instalá zsh/starship/neovim/tmux/lazygit con el package manager del sistema si faltan"
fi
echo ""
echo "  Para medir el load time:"
echo "  \$ time zsh -i -c exit"
echo ""
