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
    set -gx CORTEX_MULTIPLEXER herdr
end
set -gx CLAUDE_CODE_EFFORT_LEVEL high
if not set -q WORK_PROJECTS_DIR; or test -z "$WORK_PROJECTS_DIR"
    set -gx WORK_PROJECTS_DIR "$WORKSPACE_DIR/innit-sas"
end
if not set -q PERSONAL_PROJECTS_DIR; or test -z "$PERSONAL_PROJECTS_DIR"
    set -gx PERSONAL_PROJECTS_DIR "$BARBATDEV_DIR/products"
end
if not set -q INNIT_DIR; or test -z "$INNIT_DIR"
    set -gx INNIT_DIR "$WORKSPACE_DIR/innit-sas"
end

if not set -q REFACTORIA_DIR; or test -z "$REFACTORIA_DIR"
    set -gx REFACTORIA_DIR "$WORKSPACE_DIR/refactoria"
end

if not set -q GENTLE_DIR; or test -z "$GENTLE_DIR"
    set -gx GENTLE_DIR "$WORKSPACE_DIR/gentle"
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

if test (uname) = Darwin
    # This file owns the macOS PATH; config.fish must not edit it, because it
    # loads after conf.d and would bury the entries below (and gentle-ai's).
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew
        if test -x $brew_bin
            $brew_bin shellenv fish | source
            break
        end
    end
    # Later entries end up first (fish_add_path --move prepends).
    for tool_bin in /usr/local/bin /nix/var/nix/profiles/default/bin "$HOME/.nix-profile/bin" "$HOME/.bun/bin" "$HOME/.volta/bin" "$HOME/.opencode/bin" "$HOME/.local/bin" /opt/homebrew/sbin /opt/homebrew/bin "$HOME/.cargo/bin"
        if test -d "$tool_bin"
            fish_add_path --path --move "$tool_bin"
        end
    end
end

if test (uname) = Linux
    # One list for every Linux host; each dir is added only if it exists.
    # Later entries end up first (fish_add_path --move prepends).
    for tool_bin in /usr/local/go/bin $HOME/.local/go-*/bin "$HOME/.bun/bin" "$HOME/.local/share/pnpm/bin" /nix/var/nix/profiles/default/bin "$HOME/.nix-profile/bin" "$HOME/.opencode/bin" "$HOME/.local/bin"
        if test -d "$tool_bin"
            fish_add_path --path --move "$tool_bin"
        end
    end
end

alias g git
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

if test (uname) = Darwin
    alias o open
end

if command -q eza
    alias ll 'eza -la --icons --git'
    alias la 'eza -la --icons --git --all'
    alias lt 'eza --tree --icons --level=2'
else
    alias ll 'ls -lah'
    alias la 'ls -lah -A'
end

# gs sync installs the Gentle stack from main, so every host follows the beta
# channel for gentle-ai install/upgrade and engram downloads.
if not set -q GENTLE_AI_CHANNEL; or test -z "$GENTLE_AI_CHANNEL"
    set -gx GENTLE_AI_CHANNEL beta
end

# gentle-ai's managed launchers (OpenCode background subagents) must win on PATH;
# gentle-ai cannot persist PATH for fish login shells by itself.
if test -d "$HOME/.gentle-ai/bin"
    fish_add_path --path --move "$HOME/.gentle-ai/bin"
end

if status is-interactive; and command -q starship
    starship init fish | source
end
