#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

workspace="$tmp_dir/dev"
mkdir -p \
    "$workspace/barbatdev/cortex/cortex-dotfiles" \
    "$workspace/innit-sas/apis" \
    "$workspace/innit-sas/mobile" \
    "$workspace/innit-sas/webs" \
    "$workspace/innit-sas/pcsoft" \
    "$workspace/local/tools" \
    "$workspace/worktrees"

env -u BARBATDEV_DIR -u WORK_PROJECTS_DIR -u PERSONAL_PROJECTS_DIR \
    -u TOOLS_DIR -u WORKTREES_DIR -u INNIT_DIR -u INNIT_APIS_DIR \
    -u INNIT_MOBILE_DIR -u INNIT_WEBS_DIR -u INNIT_PCSOFT_DIR \
    -u CORTEX_DOTFILES_DIR WORKSPACE_DIR="$workspace" zsh -f -c '
        source "$1" >/dev/null
        check_navigation() {
            local command="$1"
            local expected="$2"
            "$command"
            [[ "$PWD" == "$expected" ]]
        }

        check_navigation dev "$WORKSPACE_DIR"
        check_navigation barbat "$BARBATDEV_DIR"
        check_navigation cowork "$WORK_PROJECTS_DIR"
        check_navigation work "$WORK_PROJECTS_DIR"
        check_navigation innit "$INNIT_DIR"
        check_navigation personal "$PERSONAL_PROJECTS_DIR"
        check_navigation tools "$TOOLS_DIR"
        check_navigation worktrees "$WORKTREES_DIR"
        check_navigation innit-apis "$INNIT_APIS_DIR"
        check_navigation innit-mobile "$INNIT_MOBILE_DIR"
        check_navigation innit-webs "$INNIT_WEBS_DIR"
        check_navigation innit-pcsoft "$INNIT_PCSOFT_DIR"
        check_navigation dotfiles "$CORTEX_DOTFILES_DIR"
    ' _ "$repo_root/zsh/cortex-dotfiles.zsh"

fixture="$tmp_dir/fixture"
mkdir -p "$fixture/zsh" "$fixture/local"
cp "$repo_root/zsh/cortex-dotfiles.zsh" "$fixture/zsh/cortex-dotfiles.zsh"
printf 'export WORKSPACE_DIR=%q\n' "$tmp_dir/custom-workspace" > "$fixture/local/env.zsh"

env -u WORKSPACE_DIR -u BARBATDEV_DIR -u WORK_PROJECTS_DIR \
    -u PERSONAL_PROJECTS_DIR -u TOOLS_DIR -u WORKTREES_DIR \
    zsh -f -c '
        source "$1" >/dev/null
        [[ "$WORKSPACE_DIR" == "$2" ]]
        [[ "$BARBATDEV_DIR" == "$2/barbatdev" ]]
        [[ "$WORK_PROJECTS_DIR" == "$2/innit-sas" ]]
        [[ "$PERSONAL_PROJECTS_DIR" == "$2/local" ]]
        [[ "$TOOLS_DIR" == "$2/local/tools" ]]
        [[ "$WORKTREES_DIR" == "$2/worktrees" ]]
    ' _ "$fixture/zsh/cortex-dotfiles.zsh" "$tmp_dir/custom-workspace"
