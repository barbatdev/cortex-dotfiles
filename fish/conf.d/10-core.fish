# Core Fish defaults. Host overrides load later from 99-local.fish.

if not set -q WORKSPACE_DIR; or test -z "$WORKSPACE_DIR"
    set -gx WORKSPACE_DIR "$HOME/dev"
end
if not set -q BARBATDEV_DIR; or test -z "$BARBATDEV_DIR"
    set -gx BARBATDEV_DIR "$WORKSPACE_DIR/barbatdev"
end
if not set -q CORTEX_HOME; or test -z "$CORTEX_HOME"
    set -gx CORTEX_HOME "$HOME/.cortex"
end
if not set -q CORTEX_ROOT; or test -z "$CORTEX_ROOT"
    set -gx CORTEX_ROOT "$BARBATDEV_DIR/cortex/cortex"
end
if not set -q CORTEX_DOTFILES_DIR; or test -z "$CORTEX_DOTFILES_DIR"
    set -gx CORTEX_DOTFILES_DIR "$BARBATDEV_DIR/cortex/cortex-dotfiles"
end
if not set -q CORTEX_MULTIPLEXER; or test -z "$CORTEX_MULTIPLEXER"
    set -gx CORTEX_MULTIPLEXER cmux
end
set -gx CLAUDE_CODE_EFFORT_LEVEL high
if not set -q WORK_PROJECTS_DIR; or test -z "$WORK_PROJECTS_DIR"
    set -gx WORK_PROJECTS_DIR "$BARBATDEV_DIR/innit"
end
if not set -q PERSONAL_PROJECTS_DIR; or test -z "$PERSONAL_PROJECTS_DIR"
    set -gx PERSONAL_PROJECTS_DIR "$BARBATDEV_DIR/products"
end
if not set -q INNIT_DIR; or test -z "$INNIT_DIR"
    set -gx INNIT_DIR "$BARBATDEV_DIR/innit"
end
if not set -q SCREENSHOTS_DIR; or test -z "$SCREENSHOTS_DIR"
    set -gx SCREENSHOTS_DIR "$HOME/Screenshots"
end

if command -q nvim
    set -gx EDITOR (command -s nvim)
else if command -q vim
    set -gx EDITOR (command -s vim)
else
    set -gx EDITOR nano
end
set -gx VISUAL "$EDITOR"

alias g git
alias gs 'git status'
alias ga 'git add'
alias gc 'git commit -m'
alias gp 'git push'
alias gl 'git log --oneline --graph --decorate --all'
alias gd 'git diff'
alias gco 'git checkout'
alias gb 'git branch'
alias gpl 'git pull'
alias gf 'git fetch'
alias gst 'git stash'
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias c clear
alias o open

if command -q eza
    alias ll 'eza -la --icons --git'
    alias la 'eza -la --icons --git --all'
    alias lt 'eza --tree --icons --level=2'
else
    alias ll 'ls -lah'
    alias la 'ls -lah -A'
end

if status is-interactive; and command -q starship
    starship init fish | source
end
