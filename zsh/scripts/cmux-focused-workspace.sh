#!/bin/bash

# Helper de resolución de workspace enfocado para cmux.
#
# Fuente de verdad: `cmux identify --json --no-caller` leyendo .focused.workspace_ref
# y .focused.window_ref. Los eventos window.keyed/workspace.selected son SEÑAL; este
# script re-deriva la VERDAD cada vez que se lo invoca.
#
# Este es el ÚNICO productor autorizado de ~/.cache/cortex/active-workspace (o el path
# definido por CORTEX_ACTIVE_WORKSPACE_FILE). Ningún otro script debe escribir ese cache.
#
# Salida:
#   - Imprime el cwd resuelto por stdout.
#   - Escribe ese valor en el archivo de cache.
#   - Retorna 0 en éxito; 1 si cmux no responde (degradación silenciosa, sin pisar cache).
#
# Uso: cmux-focused-workspace.sh
# Con cmux vivo se puede verificar manualmente:
#   env CMUX_SOCKET_PATH=/dev/null CMUX_SOCKET=/dev/null dotfiles/zsh/scripts/cmux-focused-workspace.sh
# El resultado debe imprimir el cwd del .focused y escribirlo en el cache.

set -euo pipefail

# Ruta del cache — respetar CORTEX_ACTIVE_WORKSPACE_FILE si está definido por el entorno.
# El fallback usa XDG_CACHE_HOME o el directorio estándar de macOS.
ACTIVE_WORKSPACE_FILE="${CORTEX_ACTIVE_WORKSPACE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/cortex/active-workspace}"

# ── Detección del binario cmux ──────────────────────────────────────────────
CMUX_BIN=""
if command -v cmux >/dev/null 2>&1; then
    CMUX_BIN="cmux"
elif [[ -x "/Applications/cmux.app/Contents/Resources/bin/cmux" ]]; then
    CMUX_BIN="/Applications/cmux.app/Contents/Resources/bin/cmux"
fi

# Sin binario disponible, degradar sin tocar el cache.
if [[ -z "$CMUX_BIN" ]]; then
    exit 1
fi

# ── Entorno limpio — neutralizar el socket muerto heredado del entorno ───────
# cmux upstream (opcode-plugin.js) inyecta CMUX_SOCKET_PATH en settings.json;
# ese path puede apuntar a un socket muerto tras un crash/reboot. Limpiar esas
# variables aquí permite que cmux auto-descubra el socket vivo en
# ~/.local/state/cmux/cmux.sock. NO hardcodeamos ningún path de socket.
CMUX="env -u CMUX_SOCKET_PATH -u CMUX_SOCKET $CMUX_BIN"

# ── Verificar que cmux responde (ping) ──────────────────────────────────────
if ! $CMUX ping >/dev/null 2>&1; then
    # cmux no responde (socket caído / proceso no levantado todavía).
    # Degradar con gracia: salir con error sin pisar el cache con un valor vacío.
    exit 1
fi

# ── Helper de extracción JSON (jq con fallback a sed) ───────────────────────
json_value() {
    local key="$1"
    local fallback_key="${key##*.}"
    if command -v jq >/dev/null 2>&1; then
        jq -r ".$key // empty" 2>/dev/null
    else
        sed -n "s/.*\"$fallback_key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
    fi
}

# ── Fuente de verdad: identify --no-caller ───────────────────────────────────
# Leer .focused.workspace_ref y .focused.window_ref para resolver el workspace
# que el usuario VE, no el workspace del caller (que puede ser distinto).
IDENTIFY_JSON=$($CMUX identify --json --no-caller 2>/dev/null || true)

if [[ -z "$IDENTIFY_JSON" ]]; then
    # identify devolvió vacío — cmux puede estar levantando, degradar sin pisar cache.
    exit 1
fi

WORKSPACE_REF=$(printf '%s' "$IDENTIFY_JSON" | json_value "focused.workspace_ref")
WINDOW_REF=$(printf '%s' "$IDENTIFY_JSON" | json_value "focused.window_ref")

if [[ -z "$WORKSPACE_REF" ]]; then
    # Sin workspace enfocado reportado, degradar sin pisar cache.
    exit 1
fi

# ── CWD del foco: sidebar-state --workspace --window ────────────────────────
# Usar workspace_ref + window_ref para evitar ambigüedad cuando hay múltiples ventanas.
SIDEBAR_OUTPUT=""
if [[ -n "$WINDOW_REF" ]]; then
    SIDEBAR_OUTPUT=$($CMUX sidebar-state --workspace "$WORKSPACE_REF" --window "$WINDOW_REF" 2>/dev/null || true)
else
    SIDEBAR_OUTPUT=$($CMUX sidebar-state --workspace "$WORKSPACE_REF" 2>/dev/null || true)
fi

# Parsear focused_cwd= (formato preferido) o cwd= (fallback de versiones anteriores).
FOCUSED_CWD=""
if [[ -n "$SIDEBAR_OUTPUT" ]]; then
    FOCUSED_CWD=$(printf '%s' "$SIDEBAR_OUTPUT" | awk '/^focused_cwd=/ { sub(/^focused_cwd=/, ""); print; exit }')
    if [[ -z "$FOCUSED_CWD" ]]; then
        FOCUSED_CWD=$(printf '%s' "$SIDEBAR_OUTPUT" | awk '/^cwd=/ { sub(/^cwd=/, ""); print; exit }')
    fi
fi

# ── Fallback: rpc extension.sidebar.snapshot ────────────────────────────────
# Si sidebar-state no entregó el cwd, intentar con el snapshot RPC.
if [[ -z "$FOCUSED_CWD" ]]; then
    SNAPSHOT_JSON=$($CMUX rpc extension.sidebar.snapshot 2>/dev/null || true)
    if [[ -n "$SNAPSHOT_JSON" ]]; then
        FOCUSED_CWD=$(printf '%s' "$SNAPSHOT_JSON" | json_value "focused_cwd")
    fi
fi

# Sin cwd resuelto, degradar sin pisar cache.
if [[ -z "$FOCUSED_CWD" ]]; then
    exit 1
fi

# ── Escribir cache y emitir por stdout ──────────────────────────────────────
# Solo este script escribe el cache; los consumidores (SketchyBar, watcher) lo leen.
mkdir -p "$(dirname "$ACTIVE_WORKSPACE_FILE")"
printf '%s\n' "$FOCUSED_CWD" > "$ACTIVE_WORKSPACE_FILE"
printf '%s\n' "$FOCUSED_CWD"
