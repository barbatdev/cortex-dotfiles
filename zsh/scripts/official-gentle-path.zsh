# Opt-in PATH for hosts migrated to the official Gentle main installers.
# Source via ~/.config/cortex-dotfiles/shell/official-gentle-path.zsh.
# Keep the user's own commands; do not expose Shell's private runtime tools.
# Later entries end up first. PNPM_HOME must beat PNPM_HOME/bin: the official
# installer's pinned pnpm puts gentle-shell and pi in PNPM_HOME, while a newer
# user pnpm puts global bins in PNPM_HOME/bin; a stale copy there would shadow
# every `gentle-shell upgrade` ("gentle-shell behind main").
#region Official Gentle PATH
for _official_gentle_bin in "$HOME/npm-global/bin" "$HOME/.local/share/pnpm/bin" "${PNPM_HOME:-$HOME/.local/share/pnpm}" "$HOME/.local/bin"; do
    if [[ -d "$_official_gentle_bin" ]]; then
        path=("$_official_gentle_bin" "${(@)path:#$_official_gentle_bin}")
    fi
done
export PATH
unset _official_gentle_bin
#endregion

#region gentle-shell update
# The official installer owns gentle-shell and pi through its pinned pnpm
# (10.33.0, global/5). `gentle-shell update` runs the PATH pnpm instead, which
# leaves a duplicate in PNPM_HOME/bin and fails with "ownership could not be
# verified". Route Pi updates through the pinned pnpm; everything else passes through.
# Usage: gentle-shell update [pi-version]   (default: latest)
GENTLE_PINNED_PNPM="${GENTLE_PINNED_PNPM:-pnpm@10.33.0}"
gentle-shell() {
    if [[ "$1" != update ]] || ! command -v corepack >/dev/null; then
        command gentle-shell "$@"
        return
    fi
    local version="${2:-latest}"
    [[ "$version" == latest ]] && version="$(cd ~ && corepack "$GENTLE_PINNED_PNPM" view @earendil-works/pi-coding-agent dist-tags.latest)"
    echo "gentle-shell update: Pi $version via $GENTLE_PINNED_PNPM (official install)"
    (cd ~ && corepack "$GENTLE_PINNED_PNPM" add -g --config.minimumReleaseAge=0 --allow-build=gentle-pi \
        "@earendil-works/pi-coding-agent@$version") || return
    rehash
    command gentle-shell --version | head -2
    echo "Restart Pi to pick it up. gentle-shell itself updates with: gs sync"
}
#endregion
