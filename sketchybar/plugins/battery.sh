#!/bin/bash

# RefactorIA semantic colors; normal battery status uses a neutral near-white icon.
TEXT=0xffffffff
NORMAL=0xfff2effa
WARNING=0xffffc857
ERROR=0xffff6b8a

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
