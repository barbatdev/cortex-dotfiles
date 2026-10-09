#!/bin/bash

# Neutral audio status uses the shared near-white normal-state token.
TEXT=0xffffffff
NORMAL=0xfff2effa

volume=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)
muted=$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)

if [[ "$muted" == "true" || "$volume" == "0" ]]; then
    sketchybar --animate tanh 10 --set "$NAME" icon="󰖁" label="mute" icon.color="$NORMAL" label.color="$TEXT"
elif (( volume < 35 )); then
    sketchybar --animate tanh 10 --set "$NAME" icon="󰕿" label="$volume%" icon.color="$NORMAL" label.color="$TEXT"
elif (( volume < 70 )); then
    sketchybar --animate tanh 10 --set "$NAME" icon="󰖀" label="$volume%" icon.color="$NORMAL" label.color="$TEXT"
else
    sketchybar --animate tanh 10 --set "$NAME" icon="󰕾" label="$volume%" icon.color="$NORMAL" label.color="$TEXT"
fi
