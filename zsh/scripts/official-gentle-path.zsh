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
