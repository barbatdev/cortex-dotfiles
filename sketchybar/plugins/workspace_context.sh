#!/bin/bash

# Plugin de contexto de workspace para SketchyBar.
#
# Pinta los widgets izquierdos: git_status, work_item, sdd_status, checkpoint_timer.
#
# Fuente de verdad (modelo canónico cmux v0.64.13):
#   - Consumir el workspace enfocado desde SKETCHYBAR_WORKSPACE (cuando viene del
#     trigger workspace_change que dispara el watcher) o invocando el helper T1
#     (cmux-focused-workspace.sh), que hace cmux identify --no-caller y es el ÚNICO
#     productor de ~/.cache/cortex/active-workspace.
#   - Este script ya NO escribe el cache — eso lo hace exclusivamente T1.
#   - Ya NO usa cmux sidebar-state sin --window (que era caller-biased).
#   - Si T1 no está disponible o no responde, se lee el cache como fallback (solo lectura).

workspace_file="${CORTEX_ACTIVE_WORKSPACE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/cortex/active-workspace}"
plugin_dir="$(cd "$(dirname "$0")" && pwd)"

# Ruta al helper T1 — productor único de verdad y del cache.
helper="$plugin_dir/../../zsh/scripts/cmux-focused-workspace.sh"

repo="${SKETCHYBAR_WORKSPACE:-}"

realpath_portable() {
    local target="$1"
    if command -v realpath >/dev/null 2>&1; then
        realpath "$target"
    else
        python3 - <<'PY2' "$target"
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY2
    fi
}

normalize_repo() {
    local path="$1"
    local root=""

    if [[ -n "$path" && -d "$path" ]]; then
        path=$(realpath_portable "$path")
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

# Resolución del workspace enfocado:
#   1. SKETCHYBAR_WORKSPACE (pasado por el watcher via --trigger workspace_change).
#   2. Helper T1 (cmux-focused-workspace.sh): cmux identify --no-caller, fuente de verdad.
#      T1 también actualiza el cache. Solo se invoca si SKETCHYBAR_WORKSPACE está vacío.
#   3. Cache ~/.cache/cortex/active-workspace: fallback de solo lectura (no se escribe aquí).
#
# Este script ya NO invoca cmux sidebar-state sin --window (era caller-biased)
# ni escribe el cache (eso lo hace exclusivamente el helper T1).
if [[ -z "$repo" ]]; then
    if [[ -x "$helper" ]]; then
        # T1 escribe el cache y emite el cwd por stdout.
        repo=$("$helper" 2>/dev/null) || true
    fi
fi

if [[ -z "$repo" && -f "$workspace_file" ]]; then
    # Fallback de solo lectura: leer el cache dejado por una invocación previa de T1.
    repo=$(sed -n '1p' "$workspace_file")
fi

repo="${repo:-$HOME/cortex}"
repo=$(normalize_repo "$repo")

github_issues_url() {
    local remote slug
    remote=$(git -C "$repo" remote get-url origin 2>/dev/null || true)
    case "$remote" in
        https://github.com/*) slug="${remote#https://github.com/}" ;;
        git@github.com:*) slug="${remote#git@github.com:}" ;;
        ssh://git@github.com/*) slug="${remote#ssh://git@github.com/}" ;;
        *) return 0 ;;
    esac
    slug="${slug%.git}"
    [[ "$slug" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || return 0
    [[ -n "$slug" ]] && printf 'https://github.com/%s/issues\n' "$slug"
}

set_item() {
    sketchybar --set "$@"
}

if [[ -d "$repo/.git" || -f "$repo/.git" ]]; then
    project=$(basename "$repo")
    branch=$(git -C "$repo" branch --show-current 2>/dev/null)
    dirty=$(git -C "$repo" status --porcelain 2>/dev/null)
    branch="${branch:-detached}"
    git_color=0xff3fb950
    git_label="$project:$branch"
    if [[ -n "$dirty" ]]; then
        git_color=0xfff59e0b
        git_label="$project:$branch*"
    fi
    set_item git_status icon="󰊢" label="$git_label" icon.color="$git_color" label.max_chars=28
    set_item git_status.lg icon="󰊢" label="$git_label" icon.color="$git_color" label.max_chars=24
    set_item git_status.vertical icon="󰊢" label="$git_label" icon.color="$git_color" label.max_chars=22
else
    set_item git_status icon="󰊢" label="no git" icon.color=0xff94a3b8
    set_item git_status.lg icon="󰊢" label="no git" icon.color=0xff94a3b8
    set_item git_status.vertical icon="󰊢" label="no git" icon.color=0xff94a3b8
fi

item_file="$repo/.ai/current-work-item"
work_label="work"
work_color=0xff94a3b8
issues_url=$(github_issues_url)
work_click=""
[[ -n "$issues_url" ]] && work_click="open '$issues_url'"

if [[ -f "$item_file" ]]; then
    item=$(tr -d '[:space:]' < "$item_file")
    if [[ "$item" =~ ^#?[0-9]+$ ]]; then
        number="${item#\#}"
        work_label="#$number"
        work_color=0xff38bdf8
        [[ -n "$issues_url" ]] && work_click="open '$issues_url/$number'"
    elif [[ -n "$item" ]]; then
        work_label="$item"
        work_color=0xff38bdf8
    fi
elif [[ -n "$branch" ]]; then
    number=$(printf '%s' "$branch" | grep -Eo '[0-9]+' | head -1)
    if [[ -n "$number" ]]; then
        work_label="#$number"
        work_color=0xff38bdf8
        [[ -n "$issues_url" ]] && work_click="open '$issues_url/$number'"
    else
        work_label="no issue"
    fi
fi
set_item work_item icon="󰛢" label="$work_label" icon.color="$work_color" click_script="$work_click"
set_item work_item.lg icon="󰛢" label="$work_label" icon.color="$work_color" click_script="$work_click"
set_item work_item.vertical icon="󰛢" label="$work_label" icon.color="$work_color" click_script="$work_click"

global_helper="$HOME/.claude/scripts/sdd-helper.sh"
cortex_helper="${CORTEX_ROOT:-$HOME/cortex}/scripts/sdd-helper.sh"
sdd_color=0xff94a3b8
sdd_label="no sdd"
if [[ -x "$global_helper" ]]; then
    json=$("$global_helper" sdd-resume-context.sh get "$repo" 2>/dev/null)
elif [[ -x "$cortex_helper" ]]; then
    json=$("$cortex_helper" sdd-resume-context.sh get "$repo" 2>/dev/null)
fi
if [[ -n "$json" ]]; then
    status=$(printf '%s' "$json" | json_value status)
    checkpoint=$(printf '%s' "$json" | json_value checkpoint_status)
    feature=$(printf '%s' "$json" | json_value feature)
    if [[ "$status" == "ready" && "$checkpoint" == "present" ]]; then
        sdd_color=0xff3fb950
        sdd_label="${feature:-ready}"
    elif [[ "$status" == "ambiguous_feature" ]]; then
        sdd_color=0xfff59e0b
        sdd_label="ambiguous"
    elif [[ "$checkpoint" == "stale_feature" || "$checkpoint" == "invalid" ]]; then
        sdd_color=0xfff59e0b
        sdd_label="$checkpoint"
    elif [[ "$status" == "missing_mode" && -n "$feature" ]]; then
        sdd_color=0xfff59e0b
        sdd_label="$feature"
    elif [[ -n "$status" ]]; then
        sdd_label="$status"
    fi
fi
set_item sdd_status icon="󰦨" label="$sdd_label" icon.color="$sdd_color" label.max_chars=18
set_item sdd_status.lg icon="󰦨" label="$sdd_label" icon.color="$sdd_color" label.max_chars=16
set_item sdd_status.vertical icon="󰦨" label="$sdd_label" icon.color="$sdd_color" label.max_chars=14

checkpoint_file="$repo/.ai/sdd-session.json"
timer_color=0xff94a3b8
timer_label="no timer"
if [[ -f "$checkpoint_file" ]]; then
    now=$(date +%s)
    mtime=$(stat -f %m "$checkpoint_file" 2>/dev/null || printf '%s' "$now")
    minutes=$(( (now - mtime) / 60 ))
    timer_color=0xff3fb950
    if (( minutes >= 90 )); then
        timer_color=0xffef4444
    elif (( minutes >= 45 )); then
        timer_color=0xfff59e0b
    fi
    if (( minutes >= 60 )); then
        timer_label="$((minutes / 60))h$((minutes % 60))m"
    else
        timer_label="${minutes}m"
    fi
fi
set_item checkpoint_timer icon="󰔟" label="$timer_label" icon.color="$timer_color"
set_item checkpoint_timer.lg icon="󰔟" label="$timer_label" icon.color="$timer_color"
set_item checkpoint_timer.vertical icon="󰔟" label="$timer_label" icon.color="$timer_color"
