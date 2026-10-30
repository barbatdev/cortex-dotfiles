#!/bin/bash

source "${CONFIG_DIR:-$HOME/.config/sketchybar}/colors.sh"

# Selected spaces use the raised surface with a readable brand outline; inactive spaces stay neutral.
if [[ "$SELECTED" == "true" ]]; then
    sketchybar --animate tanh 10 --set "$NAME" \
        icon.color="$COLOR_TEXT" \
        background.color="$COLOR_RAISED" \
        background.border_color="$COLOR_ACCENT_TEXT" \
        background.border_width=1
else
    sketchybar --animate tanh 10 --set "$NAME" \
        icon.color="$COLOR_MUTED" \
        background.color="$COLOR_PILL_SOFT" \
        background.border_color="$COLOR_TRANSPARENT" \
        background.border_width=0
fi
