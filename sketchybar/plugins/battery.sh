#!/bin/bash

info=$(pmset -g batt 2>/dev/null)
percent=$(printf '%s' "$info" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')

if [[ -z "$percent" ]]; then
    sketchybar --set "$NAME" icon="󰂑" label="--"
    exit 0
fi

icon="󰁹"
color=0xfff8fafc

if printf '%s' "$info" | grep -qi 'AC Power'; then
    icon="󰂄"
    color=0xff3fb950
elif (( percent <= 15 )); then
    icon="󰁺"
    color=0xffef4444
elif (( percent <= 35 )); then
    icon="󰁼"
    color=0xfff59e0b
fi

sketchybar --animate tanh 10 --set "$NAME" icon="$icon" icon.color="$color" label="$percent%"
