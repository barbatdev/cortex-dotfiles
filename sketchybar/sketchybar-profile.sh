#!/bin/bash

set -euo pipefail

profile="${1:-auto}"
profile_file="${XDG_CACHE_HOME:-$HOME/.cache}/cortex/sketchybar-profile"

case "$profile" in
    auto|portable|office)
        ;;
    *)
        echo "Uso: $0 [auto|portable|office]" >&2
        exit 2
        ;;
esac

mkdir -p "$(dirname "$profile_file")"
printf '%s\n' "$profile" > "$profile_file"
"${HOME}/.config/sketchybar/sketchybarrc"
