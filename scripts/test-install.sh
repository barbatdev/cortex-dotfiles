#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d)"
INSTALL_MODE="copy"

for arg in "$@"; do
    case "$arg" in
        --symlink)
            INSTALL_MODE="symlink"
            ;;
        *)
            printf 'Usage: %s [--symlink]\n' "$0" >&2
            exit 1
            ;;
    esac
done

cleanup() {
    rm -rf "$TMP_HOME"
}
trap cleanup EXIT

fail() {
    printf 'FAIL %s\n' "$*" >&2
    exit 1
}

assert_file() {
    [[ -f "$1" ]] || fail "expected file: $1"
}

assert_dir() {
    [[ -d "$1" ]] || fail "expected directory: $1"
}

assert_symlink() {
    [[ -L "$1" ]] || fail "expected symlink: $1"
}

assert_not_symlink() {
    [[ ! -L "$1" ]] || fail "expected non-symlink: $1"
}

export HOME="$TMP_HOME/home"
export XDG_CONFIG_HOME="$TMP_HOME/config"
export CORTEX_CONFIG_HOME="$XDG_CONFIG_HOME/cortex-dotfiles"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"

install_args=()
if [[ "$INSTALL_MODE" == "symlink" ]]; then
    install_args+=(--symlink)
fi

bash "$ROOT_DIR/install.sh" "${install_args[@]}"

assert_file "$HOME/.zshrc"
assert_dir "$CORTEX_CONFIG_HOME/zsh/scripts"
assert_dir "$CORTEX_CONFIG_HOME/assets"
assert_file "$HOME/.npmrc"
assert_file "$XDG_CONFIG_HOME/pnpm/rc"
assert_file "$HOME/.bunfig.toml"
assert_file "$HOME/.config/uv/uv.toml"
assert_file "$HOME/.config/starship.toml"
assert_file "$HOME/.config/herdr/config.toml"
assert_file "$HOME/.config/ghostty/config"
assert_dir "$HOME/.config/ghostty/shaders"
assert_file "$HOME/.tmux.conf"
assert_file "$HOME/.config/lazygit/config.yml"
assert_file "$CORTEX_CONFIG_HOME/local/env.zsh"
assert_file "$CORTEX_CONFIG_HOME/install.log"

if [[ "$INSTALL_MODE" == "symlink" ]]; then
    assert_symlink "$HOME/.zshrc"
    assert_symlink "$CORTEX_CONFIG_HOME/zsh/scripts"
    assert_symlink "$CORTEX_CONFIG_HOME/assets"
    assert_symlink "$HOME/.config/ghostty/shaders"
else
    assert_not_symlink "$HOME/.zshrc"
    assert_not_symlink "$CORTEX_CONFIG_HOME/zsh/scripts"
    assert_not_symlink "$CORTEX_CONFIG_HOME/assets"
    assert_not_symlink "$HOME/.config/ghostty/shaders"
fi

printf 'PASS install flow (%s)\n' "$INSTALL_MODE"
