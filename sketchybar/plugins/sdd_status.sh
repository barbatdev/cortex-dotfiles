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

json_value() {
    local key="$1"
    local fallback_key="${key##*.}"
    if command -v jq >/dev/null 2>&1; then
        jq -r ".$key // empty" 2>/dev/null
    else
        sed -n "s/.*\"$fallback_key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
    fi
}

if [[ -z "$repo" && -f "$workspace_file" ]]; then
    repo=$(sed -n '1p' "$workspace_file")
fi
repo=$(normalize_repo "${repo:-$HOME/cortex}")
global_helper="$HOME/.claude/scripts/sdd-helper.sh"
cortex_helper="${CORTEX_ROOT:-$HOME/cortex}/scripts/sdd-helper.sh"

if [[ -x "$global_helper" ]]; then
    json=$("$global_helper" sdd-resume-context.sh get "$repo" 2>/dev/null)
elif [[ -x "$cortex_helper" ]]; then
    json=$("$cortex_helper" sdd-resume-context.sh get "$repo" 2>/dev/null)
else
    sketchybar --set "$NAME" icon="󰦨" label="no sdd" icon.color=0xff94a3b8
    exit 0
fi

status=$(printf '%s' "$json" | json_value status)
checkpoint=$(printf '%s' "$json" | json_value checkpoint_status)
feature=$(printf '%s' "$json" | json_value feature)

color=0xff94a3b8
label="sdd ?"

if [[ "$status" == "ready" && "$checkpoint" == "present" ]]; then
    color=0xff3fb950
    label="${feature:-ready}"
elif [[ "$status" == "ambiguous_feature" ]]; then
    color=0xfff59e0b
    label="ambiguous"
elif [[ "$checkpoint" == "stale_feature" || "$checkpoint" == "invalid" ]]; then
    color=0xfff59e0b
    label="$checkpoint"
elif [[ "$status" == "missing_mode" && -n "$feature" ]]; then
    color=0xfff59e0b
    label="$feature"
elif [[ -n "$status" ]]; then
    label="$status"
fi

sketchybar --set "$NAME" icon="󰦨" label="$label" icon.color="$color" label.max_chars=18
