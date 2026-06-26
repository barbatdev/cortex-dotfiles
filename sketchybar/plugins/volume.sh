#!/bin/bash

volume=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)
muted=$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)

if [[ "$muted" == "true" || "$volume" == "0" ]]; then
    sketchybar --animate tanh 10 --set "$NAME" icon="󰖁" label="mute" icon.color=0xff94a3b8
elif (( volume < 35 )); then
    sketchybar --animate tanh 10 --set "$NAME" icon="󰕿" label="$volume%" icon.color=0xff94a3b8
elif (( volume < 70 )); then
    sketchybar --animate tanh 10 --set "$NAME" icon="󰖀" label="$volume%" icon.color=0xff94a3b8
else
    sketchybar --animate tanh 10 --set "$NAME" icon="󰕾" label="$volume%" icon.color=0xff94a3b8
fi
