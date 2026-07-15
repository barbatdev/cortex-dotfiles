#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

integration="$tmp_dir/cortex.zsh"
printf '%s\n' '_CORTEX_INTEGRATION_PROBE=loaded' > "$integration"

env CORTEX_SHELL_INTEGRATION="$integration" zsh -f -c '
    source "$1" >/dev/null
    [[ "$_CORTEX_INTEGRATION_PROBE" == loaded ]]
    (( ! ${+_CORTEX_SHELL_INTEGRATION_PATH} ))
' _ "$repo_root/zsh/zshrc"

env CORTEX_SHELL_INTEGRATION="$tmp_dir/missing.zsh" zsh -f -c '
    source "$1" >/dev/null
    (( ! ${+_CORTEX_INTEGRATION_PROBE} ))
' _ "$repo_root/zsh/zshrc"

mkdir -p "$tmp_dir/cortex-home/shell"
printf '%s\n' '_CORTEX_DEFAULT_INTEGRATION_PROBE=loaded' > "$tmp_dir/cortex-home/shell/cortex.zsh"

env -u CORTEX_SHELL_INTEGRATION CORTEX_HOME="$tmp_dir/cortex-home" zsh -f -c '
    source "$1" >/dev/null
    [[ "$_CORTEX_DEFAULT_INTEGRATION_PROBE" == loaded ]]
' _ "$repo_root/zsh/zshrc"
