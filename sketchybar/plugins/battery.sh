#!/bin/bash

source "${CONFIG_DIR:-$HOME/.config/sketchybar}/colors.sh"

# RefactorIA semantic colors; normal battery status uses a neutral near-white icon.
TEXT="$COLOR_TEXT"
NORMAL="$COLOR_NORMAL"
WARNING="$COLOR_WARN"
ERROR="$COLOR_DANGER"

info=$(pmset -g batt 2>/dev/null)
percent=$(printf '%s' "$info" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')

if [[ -z "$percent" ]]; then
    sketchybar --set "$NAME" icon="󰂑" label="--" label.color="$TEXT"
    exit 0
fi

icon="󰁹"
color=$NORMAL

if printf '%s' "$info" | grep -qi 'AC Power'; then
    icon="󰂄"
    color=$NORMAL
elif (( percent <= 15 )); then
    icon="󰁺"
    color=$ERROR
elif (( percent <= 35 )); then
    icon="󰁼"
    color=$WARNING
fi

sketchybar --animate tanh 10 --set "$NAME" icon="$icon" icon.color="$color" label="$percent%" label.color="$TEXT"
