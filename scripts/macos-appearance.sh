#!/bin/bash
# macos-appearance.sh — Apply the RefactorIA look to macOS system appearance.
# Usage: scripts/macos-appearance.sh [--dry-run]
# Sets dark mode, the purple accent and a #A477FF text highlight. macOS has no
# custom accent hex, so purple (5) is the closest preset to brand-500 #7127FF.
# Wallpaper and icon tint are not scriptable with defaults; set them by hand.
set -e

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "  - apariencia macOS omitida en $(uname -s)"
    exit 0
fi

# #A477FF as normalized RGB, plus the "Other" label macOS uses for custom colors.
HIGHLIGHT="0.643137 0.466667 1.000000 Other"

apply() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "  → Would run: $*"
    else
        "$@"
    fi
}

apply defaults write -g AppleInterfaceStyle -string Dark
apply defaults write -g AppleAccentColor -int 5
apply defaults write -g AppleHighlightColor -string "$HIGHLIGHT"
# Switch dark mode live; the defaults keys apply to apps on their next launch.
DARK_MODE='tell application "System Events" to tell appearance preferences to set dark mode to true'
if [[ "$DRY_RUN" == true ]]; then
    echo "  → Would run: osascript -e '$DARK_MODE'"
elif ! osascript -e "$DARK_MODE" >/dev/null 2>&1; then
    echo "  ! No se pudo activar el modo oscuro en vivo; se aplica al reabrir la sesión"
fi

if [[ "$DRY_RUN" != true ]]; then
    echo "  ✓ Apariencia macOS: modo oscuro, acento morado, resaltado #A477FF"
    echo "    Fondo de pantalla (#0B0714) y tinte de íconos: configuralos a mano en Ajustes del Sistema"
fi
