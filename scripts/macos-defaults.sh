#!/usr/bin/env bash
# macos-defaults.sh — Optional workstation defaults. Run manually on macOS only.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '%s\n' "macOS defaults skipped: this script only runs on Darwin."
    exit 0
fi

printf '%s\n' "Applying macOS defaults..."

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false

# Finder
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Keyboard
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Screenshots
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true

printf '%s\n' "macOS defaults applied."
