# Usage: dotfiles — change to the Cortex dotfiles repository.
function dotfiles
    if set -q _DOTFILES_DIR; and test -n "$_DOTFILES_DIR"
        _go_dev_dir "$_DOTFILES_DIR"
    else
        _go_dev_dir "$CORTEX_DOTFILES_DIR"
    end
end
