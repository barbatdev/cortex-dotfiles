#!/bin/bash

state=$(osascript -e 'tell application "Music" to player state as text' 2>/dev/null)

if [[ "$state" != "playing" && "$state" != "paused" ]]; then
    sketchybar --set "$NAME" label="" drawing=off
    exit 0
fi

title=$(osascript -e 'tell application "Music" to name of current track' 2>/dev/null)
artist=$(osascript -e 'tell application "Music" to artist of current track' 2>/dev/null)

if [[ -z "$title" ]]; then
    sketchybar --set "$NAME" label="" drawing=off
    exit 0
fi

icon="󰎆"
if [[ "$state" == "paused" ]]; then
    icon="󰏤"
fi

sketchybar --set "$NAME" drawing=on icon="$icon" label="$title - $artist"
