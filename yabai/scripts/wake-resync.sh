#!/bin/bash
# wake-resync.sh — Re-sincroniza yabai tras despertar de suspensión.
#
# Al despertar, macOS re-enumera los displays en etapas (la laptop despierta
# antes que los monitores externos) y yabai queda con ventanas mal ubicadas.
# Reiniciar el Dock fuerza a yabai a re-observar y re-distribuir las ventanas.
#
# Uso: invocado por la signal `display_changed` de yabai (ver yabairc).
# Debounce: lockfile con timestamp; eventos repetidos dentro del window de
# debounce disparan un único restart del Dock. El restart del Dock no vuelve
# a disparar display_changed, así que no hay bucle.

set -eu

LOCK="${TMPDIR:-/tmp}/yabai-wake-resync.lock"
DEBOUNCE=10   # segundos
SETTLE=5      # segundos de espera para que los displays terminen de aparecer

now=$(date +%s)
if [[ -f "$LOCK" ]]; then
    last=$(cat "$LOCK" 2>/dev/null || echo 0)
    if (( now - last < DEBOUNCE )); then
        exit 0
    fi
fi
echo "$now" > "$LOCK"

sleep "$SETTLE"
killall Dock
