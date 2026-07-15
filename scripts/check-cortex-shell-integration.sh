#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

dotfiles_fragment="$tmp_dir/cortex-dotfiles.zsh"
cortex_fragment="$tmp_dir/cortex.zsh"
printf '%s\n' '_SHELL_LOAD_ORDER+=(dotfiles)' > "$dotfiles_fragment"
printf '%s\n' '_SHELL_LOAD_ORDER+=(cortex)' > "$cortex_fragment"

env \
    CORTEX_DOTFILES_SHELL_ENTRYPOINT="$dotfiles_fragment" \
    CORTEX_SHELL_INTEGRATION="$cortex_fragment" \
    zsh -f -c '
        _SHELL_LOAD_ORDER=()
        source "$1"
        [[ "${(j/:/)_SHELL_LOAD_ORDER}" == "dotfiles:cortex" ]]
        (( ! ${+_CORTEX_DOTFILES_SHELL_PATH} ))
        (( ! ${+_CORTEX_SHELL_PATH} ))
    ' _ "$repo_root/zsh/zshrc"

home_dir="$tmp_dir/home"
mkdir -p "$home_dir/.config/cortex-dotfiles/shell" "$home_dir/.cortex/shell"
cp "$dotfiles_fragment" "$home_dir/.config/cortex-dotfiles/shell/cortex-dotfiles.zsh"
cp "$cortex_fragment" "$home_dir/.cortex/shell/cortex.zsh"

env -u CORTEX_HOME -u CORTEX_ROOT -u CORTEX_DOTFILES_SHELL_ENTRYPOINT \
    -u CORTEX_SHELL_INTEGRATION HOME="$home_dir" zsh -f -c '
        _SHELL_LOAD_ORDER=()
        source "$1"
        [[ "${(j/:/)_SHELL_LOAD_ORDER}" == "dotfiles:cortex" ]]
        (( ! ${+CORTEX_HOME} ))
        (( ! ${+CORTEX_ROOT} ))
    ' _ "$repo_root/zsh/zshrc"

env HOME="$tmp_dir/missing-home" zsh -f -c 'source "$1"' _ "$repo_root/zsh/zshrc"

printf '%s\n' 'return 1' > "$dotfiles_fragment"
env \
    CORTEX_DOTFILES_SHELL_ENTRYPOINT="$dotfiles_fragment" \
    CORTEX_SHELL_INTEGRATION="$cortex_fragment" \
    zsh -f -c '
        _SHELL_LOAD_ORDER=()
        source "$1" 2>"$2"
        [[ "${(j/:/)_SHELL_LOAD_ORDER}" == "cortex" ]]
    ' _ "$repo_root/zsh/zshrc" "$tmp_dir/error.log"

grep -Fq "zsh: no se pudo cargar cortex-dotfiles: $dotfiles_fragment" "$tmp_dir/error.log"

printf '%s\n' 'if [[' > "$dotfiles_fragment"
env \
    CORTEX_DOTFILES_SHELL_ENTRYPOINT="$dotfiles_fragment" \
    CORTEX_SHELL_INTEGRATION="$cortex_fragment" \
    zsh -f -c '
        _SHELL_LOAD_ORDER=()
        source "$1" 2>/dev/null
        [[ "${(j/:/)_SHELL_LOAD_ORDER}" == "cortex" ]]
    ' _ "$repo_root/zsh/zshrc"
