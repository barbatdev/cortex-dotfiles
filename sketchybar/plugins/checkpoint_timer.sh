#!/bin/bash

workspace_file="${CORTEX_ACTIVE_WORKSPACE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/cortex/active-workspace}"
repo="${SKETCHYBAR_WORKSPACE:-}"

normalize_repo() {
    local path="$1"
    local root=""

    if [[ -n "$path" && -d "$path" ]]; then
        root=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null)
        if [[ -n "$root" ]]; then
            printf '%s\n' "$root"
            return
        fi
    fi

    printf '%s\n' "$path"
}

if [[ -z "$repo" && -f "$workspace_file" ]]; then
    repo=$(sed -n '1p' "$workspace_file")
fi
repo=$(normalize_repo "${repo:-$HOME/cortex}")
checkpoint="$repo/.ai/sdd-session.json"

if [[ ! -f "$checkpoint" ]]; then
    sketchybar --set "$NAME" icon="󰔟" label="no timer" icon.color=0xff94a3b8
    exit 0
fi

now=$(date +%s)
mtime=$(stat -f %m "$checkpoint" 2>/dev/null || printf '%s' "$now")
minutes=$(( (now - mtime) / 60 ))

color=0xff3fb950
if (( minutes >= 90 )); then
    color=0xffef4444
elif (( minutes >= 45 )); then
    color=0xfff59e0b
fi

if (( minutes >= 60 )); then
    label="$((minutes / 60))h$((minutes % 60))m"
else
    label="${minutes}m"
fi

sketchybar --set "$NAME" icon="󰔟" label="$label" icon.color="$color"
