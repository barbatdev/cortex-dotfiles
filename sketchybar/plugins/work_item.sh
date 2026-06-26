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

github_issues_url() {
    local remote slug
    remote=$(git -C "$repo" remote get-url origin 2>/dev/null || true)
    case "$remote" in
        https://github.com/*)
            slug="${remote#https://github.com/}"
            ;;
        git@github.com:*)
            slug="${remote#git@github.com:}"
            ;;
        ssh://git@github.com/*)
            slug="${remote#ssh://git@github.com/}"
            ;;
        *)
            return 0
            ;;
    esac
    slug="${slug%.git}"
    [[ "$slug" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || return 0
    [[ -n "$slug" ]] && printf 'https://github.com/%s/issues\n' "$slug"
}

if [[ -z "$repo" && -f "$workspace_file" ]]; then
    repo=$(sed -n '1p' "$workspace_file")
fi
repo=$(normalize_repo "${repo:-$HOME/cortex}")
item_file="$repo/.ai/current-work-item"
issues_url=$(github_issues_url)

label="work"
color=0xff94a3b8
click_script=""
[[ -n "$issues_url" ]] && click_script="open '$issues_url'"

if [[ -f "$item_file" ]]; then
    item=$(tr -d '[:space:]' < "$item_file")
    if [[ "$item" =~ ^#?[0-9]+$ ]]; then
        number="${item#\#}"
        label="#$number"
        color=0xff38bdf8
        [[ -n "$issues_url" ]] && click_script="open '$issues_url/$number'"
    elif [[ -n "$item" ]]; then
        label="$item"
        color=0xff38bdf8
    fi
elif [[ -d "$repo/.git" || -f "$repo/.git" ]]; then
    branch=$(git -C "$repo" branch --show-current 2>/dev/null)
    number=$(printf '%s' "$branch" | grep -Eo '[0-9]+' | head -1)
    if [[ -n "$number" ]]; then
        label="#$number"
        color=0xff38bdf8
        [[ -n "$issues_url" ]] && click_script="open '$issues_url/$number'"
    else
        label="no issue"
    fi
fi

sketchybar --set "$NAME" icon="󰛢" label="$label" icon.color="$color" click_script="$click_script"
