#!/usr/bin/env bash

set -u

target="${1:-$PWD}"
workspace="${2:-}"

command -v cmux >/dev/null 2>&1 || exit 0
cmux ping >/dev/null 2>&1 || exit 0

set_status() {
    local key="$1"
    local value="$2"

    if [[ -n "$value" && -n "$workspace" ]]; then
        cmux set-status "$key" "$value" --workspace "$workspace" >/dev/null 2>&1 || true
    elif [[ -n "$value" ]]; then
        cmux set-status "$key" "$value" >/dev/null 2>&1 || true
    elif [[ -n "$workspace" ]]; then
        cmux clear-status "$key" --workspace "$workspace" >/dev/null 2>&1 || true
    else
        cmux clear-status "$key" >/dev/null 2>&1 || true
    fi
}

git_root=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || true)
if [[ -n "$git_root" ]]; then
    project=$(basename "$git_root")
    branch=$(git -C "$git_root" branch --show-current 2>/dev/null || true)
    [[ -n "$(git -C "$git_root" status --porcelain 2>/dev/null)" ]] && branch="${branch}*"
else
    project=$(basename "$target")
    branch=""
fi

set_status project "$project"
set_status git_branch "$branch"

brains=""
for brain in work-brain life-brain second-brain; do
    if [[ -f "$HOME/.claude.json" ]] && jq -e --arg name "$brain" '.mcpServers[$name] // .projects[].mcpServers[$name]' "$HOME/.claude.json" >/dev/null 2>&1; then
        short=${brain%-brain}
        [[ "$brain" == "second-brain" ]] && short="notes"
        brains="${brains:+$brains,}$short"
    fi
done
set_status brains "$brains"

if [[ -d "$target/.ai" ]]; then
    spec=$(find "$target/.ai/specs" -maxdepth 1 -type f 2>/dev/null | sort | tail -n 1)
    set_status sdd_spec "${spec##*/}"
else
    set_status sdd_spec ""
fi
