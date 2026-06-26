#!/bin/bash

# Resolver la ruta real del script (deshace symlinks) para llegar a dotfiles/local/env.zsh.
# El plugin vive en dotfiles/sketchybar/plugins/ pero puede ser invocado vía el symlink
# ~/.config/sketchybar/plugins/. Subimos tres niveles: plugins/ → sketchybar/ → dotfiles/
# y de ahí accedemos a local/env.zsh.
_BRAINS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
_BRAINS_LOCAL_ENV="$(dirname "$(dirname "$_BRAINS_SCRIPT_DIR")")/local/env.zsh"
[ -f "$_BRAINS_LOCAL_ENV" ] && source "$_BRAINS_LOCAL_ENV"
unset _BRAINS_SCRIPT_DIR _BRAINS_LOCAL_ENV

color=0xff94a3b8
label="brains off"
ollama_url="${CORTEX_BRAINS_OLLAMA_URL:-}"
pg_host="${CORTEX_BRAINS_PG_HOST:-}"
pg_port="${CORTEX_BRAINS_PG_PORT:-5432}"
checked=0

if [[ -n "$ollama_url" ]]; then
    checked=1
    color=0xff3fb950
    label="brains ok"
    if ! curl -fsS --max-time 1 "$ollama_url" >/dev/null 2>&1; then
        color=0xfff59e0b
        label="ollama down"
    fi
fi

if [[ -n "$pg_host" ]]; then
    checked=1
    [[ "$label" == "brains off" ]] && label="brains ok" && color=0xff3fb950
    if ! nc -z -G 1 "$pg_host" "$pg_port" >/dev/null 2>&1; then
        color=0xffef4444
        label="pg down"
    fi
fi

if [[ "$checked" -eq 0 ]]; then
    label="brains off"
    color=0xff94a3b8
fi

sketchybar --set "$NAME" icon="󰇀" label="$label" icon.color="$color"
