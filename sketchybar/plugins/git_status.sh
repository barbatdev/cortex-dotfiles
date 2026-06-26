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

if [[ ! -d "$repo/.git" && ! -f "$repo/.git" ]]; then
    sketchybar --set "$NAME" icon="󰊢" label="no git" icon.color=0xff94a3b8
    exit 0
fi

branch=$(git -C "$repo" branch --show-current 2>/dev/null)
dirty=$(git -C "$repo" status --porcelain 2>/dev/null)

if [[ -z "$branch" ]]; then
    branch="detached"
fi

color=0xff3fb950
suffix=""

if [[ -n "$dirty" ]]; then
    color=0xfff59e0b
    suffix="*"
fi

sketchybar --set "$NAME" icon="󰊢" label="$branch$suffix" icon.color="$color" label.max_chars=22
