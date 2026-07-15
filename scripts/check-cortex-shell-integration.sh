#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

home_dir="$tmp_dir/home"
dotfiles_fragment="$home_dir/.config/cortex-dotfiles/shell/cortex-dotfiles.zsh"
cortex_fragment="$home_dir/.cortex/shell/cortex.zsh"
mkdir -p "$(dirname "$dotfiles_fragment")" "$(dirname "$cortex_fragment")"
printf '%s\n' '_SHELL_LOAD_ORDER+=(dotfiles)' > "$dotfiles_fragment"
printf '%s\n' '_SHELL_LOAD_ORDER+=(cortex)' > "$cortex_fragment"
printf '%s\n' '_UNTRUSTED_ENTRYPOINT_LOADED=1' > "$tmp_dir/untrusted.zsh"

env \
    HOME="$home_dir" \
    CORTEX_DOTFILES_SHELL_ENTRYPOINT="$tmp_dir/untrusted.zsh" \
    CORTEX_SHELL_INTEGRATION="$cortex_fragment" \
    zsh -f -c '
        _SHELL_LOAD_ORDER=()
        source "$1"
        [[ "${(j/:/)_SHELL_LOAD_ORDER}" == "dotfiles:cortex" ]]
        (( ! ${+_UNTRUSTED_ENTRYPOINT_LOADED} ))
        (( ! ${+_CORTEX_DOTFILES_SHELL_PATH} ))
        (( ! ${+_CORTEX_SHELL_PATH} ))
    ' _ "$repo_root/zsh/zshrc"

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
    HOME="$home_dir" \
    CORTEX_SHELL_INTEGRATION="$cortex_fragment" \
    zsh -f -c '
        _SHELL_LOAD_ORDER=()
        source "$1" 2>"$2"
        [[ "${(j/:/)_SHELL_LOAD_ORDER}" == "cortex" ]]
    ' _ "$repo_root/zsh/zshrc" "$tmp_dir/error.log"

grep -Fq "zsh: no se pudo cargar cortex-dotfiles: $dotfiles_fragment" "$tmp_dir/error.log"

printf '%s\n' 'if [[' > "$dotfiles_fragment"
env \
    HOME="$home_dir" \
    CORTEX_SHELL_INTEGRATION="$cortex_fragment" \
    zsh -f -c '
        _SHELL_LOAD_ORDER=()
        source "$1" 2>/dev/null
        [[ "${(j/:/)_SHELL_LOAD_ORDER}" == "cortex" ]]
    ' _ "$repo_root/zsh/zshrc"

rm -f "$dotfiles_fragment"
ln -s "$repo_root/zsh/cortex-dotfiles.zsh" "$dotfiles_fragment"
env HOME="$home_dir" CORTEX_SHELL_INTEGRATION="$tmp_dir/missing-cortex.zsh" zsh -f -c '
    setopt ERR_EXIT
    source "$1" >/dev/null
    source "$1" >/dev/null
    for expected in "$HOME/.local/bin" "$HOME/.opencode/bin" "$HOME/.bun/bin" "/opt/homebrew/opt/bc/bin"; do
        (( ${path[(I)$expected]} == ${path[(i)$expected]} ))
    done
' _ "$repo_root/zsh/zshrc"
