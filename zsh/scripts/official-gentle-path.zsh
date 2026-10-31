# Opt-in PATH for hosts migrated to the official Gentle main installers.
# Source via ~/.config/cortex-dotfiles/shell/official-gentle-path.zsh.
# Keep the user's own commands; do not expose Shell's private runtime tools.
#region Official Gentle PATH
for _official_gentle_bin in "$HOME/npm-global/bin" "$HOME/.local/share/pnpm/bin" "$HOME/.local/bin"; do
    if [[ -d "$_official_gentle_bin" ]]; then
        path=("$_official_gentle_bin" "${(@)path:#$_official_gentle_bin}")
    fi
done
export PATH
unset _official_gentle_bin
#endregion
