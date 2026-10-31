#!/usr/bin/env bash
# Usage: bash scripts/retire-gentle-legacy.sh [--dry-run|--apply]
# Retire only the explicitly listed legacy launchers and UI preferences.
# Preserve credentials, conversations, memory, packages, services and processes.
set -eu
umask 077

usage() {
  printf '%s\n' \
    'Usage: retire-gentle-legacy.sh [--dry-run|--apply]' \
    'Default: --dry-run. --apply moves listed artifacts into a private backup.' \
    'Does not uninstall Pi/packages or change shell startup files.' \
    'After reinstalling Shell, persist this alias in your dotfiles: alias gs=gentle-shell'
}
mode="${1:---dry-run}"
[ "$#" -le 1 ] || { usage >&2; exit 2; }
case "$mode" in
  --help|-h) usage; exit 0 ;;
  --dry-run|--apply) ;;
  *) usage >&2; exit 2 ;;
esac
: "${HOME:?HOME must be set}"
case "$HOME" in /*) ;; *) printf 'HOME must be absolute\n' >&2; exit 2 ;; esac

paths=(
  '.local/bin/gs'
  '.local/bin/gentle-ai'
  '.local/bin/gentle-shell'
  '.local/bin/gentle-ai.pre-gw'
  '.local/bin/gentle-shell.wrapper-backup'
  'go/bin/gentle-ai'
  '.pi/agent/bin/pi'
  '.pi/gentle-ai/notifications.json'
  '.pi/gentle-ai/history-capture.json'
  '.pi/gentle-ai/card-style.json'
)

# Refuse linked ancestor directories; never move through another home/tree.
for rel in "${paths[@]}"; do
  parent="$HOME"
  IFS='/' read -r -a parts <<< "$rel"
  for ((i=0; i<${#parts[@]}-1; i++)); do
    parent="$parent/${parts[$i]}"
    if [ -L "$parent" ]; then
      printf 'Refusing symlinked directory: %s\n' "$parent" >&2
      exit 1
    fi
  done
  src="$HOME/$rel"
  if [ -e "$src" ] || [ -L "$src" ]; then
    if [ ! -L "$src" ] && [ ! -f "$src" ]; then
      printf 'Unexpected artifact type: %s\n' "$src" >&2
      exit 1
    fi
  fi
done

backup=''
if [ "$mode" = '--apply' ]; then
  # mktemp avoids collisions; no existing backup is overwritten.
  backup=$(mktemp -d "$HOME/gentle-retirement.XXXXXX")
  printf 'Recovery directory: %s\n' "$backup"
fi
count=0
for rel in "${paths[@]}"; do
  src="$HOME/$rel"
  if [ -e "$src" ] || [ -L "$src" ]; then
    if [ "$mode" = '--apply' ]; then
      mkdir -p "$(dirname "$backup/$rel")"
      mv "$src" "$backup/$rel"
      printf 'Retired: %s\n' "$rel"
    else
      printf 'Would retire: %s\n' "$rel"
    fi
    count=$((count + 1))
  fi
done
printf 'Artifacts: %s\n' "$count"
printf '%s\n' 'Preserved: memory, conversations, credentials, packages, model configuration, themes, services and running processes.'
if [ "$mode" = '--apply' ]; then
  for rel in "${paths[@]}"; do
    if [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ]; then
      printf 'Verification failed: %s remains\n' "$rel" >&2
      exit 1
    fi
  done
  printf '%s\n' 'Verified: all listed legacy artifacts are absent.'
fi
