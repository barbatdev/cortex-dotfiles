#!/usr/bin/env bash
# bootstrap.sh — Clone/update cortex-dotfiles and run the installer.
set -euo pipefail

REPO_URL="${CORTEX_DOTFILES_REPO_URL:-https://github.com/barbatdev/cortex-dotfiles.git}"
DEST="${CORTEX_DOTFILES_BOOTSTRAP_DIR:-$HOME/.cortex/cortex-dotfiles}"

info() {
    printf '\033[0;32m==>\033[0m %s\n' "$1"
}

fail() {
    printf '\033[0;31m==>\033[0m %s\n' "$1" >&2
    exit 1
}

case "$(uname -s)" in
    Darwin|Linux)
        ;;
    *)
        fail "Unsupported platform: $(uname -s)"
        ;;
esac

if ! command -v git >/dev/null 2>&1; then
    fail "git is required before bootstrapping. Install git, then re-run this script."
fi

mkdir -p "$(dirname "$DEST")"

if [[ -d "$DEST/.git" ]]; then
    info "Updating existing repo at $DEST"
    git -C "$DEST" pull --ff-only
elif [[ -e "$DEST" ]]; then
    fail "$DEST exists but is not a git repo. Move it aside or set CORTEX_DOTFILES_BOOTSTRAP_DIR."
else
    info "Cloning $REPO_URL into $DEST"
    git clone "$REPO_URL" "$DEST"
fi

info "Running installer"
exec bash "$DEST/install.sh" "$@" </dev/tty
