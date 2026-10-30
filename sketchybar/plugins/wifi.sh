#!/bin/bash

source "${CONFIG_DIR:-$HOME/.config/sketchybar}/colors.sh"

# RefactorIA semantic colors; normal status icons use light violet.
TEXT="$COLOR_TEXT"
NORMAL="$COLOR_VIOLET_SOFT"
ERROR="$COLOR_DANGER"

wifi_device=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/ {getline; print $2; exit}')

if [[ -z "$wifi_device" ]]; then
    sketchybar --set "$NAME" icon="󰖪" label="no wifi" icon.color="$ERROR" label.color="$TEXT"
    exit 0
fi

ssid=$(networksetup -getairportnetwork "$wifi_device" 2>/dev/null | sed 's/^Current Wi-Fi Network: //')

if [[ -z "$ssid" || "$ssid" == *"not associated"* || "$ssid" == *"You are not associated"* ]]; then
    sketchybar --set "$NAME" icon="󰖪" label="offline" icon.color="$ERROR" label.color="$TEXT"
else
    sketchybar --set "$NAME" icon="󰖩" label="$ssid" icon.color="$NORMAL" label.color="$TEXT" label.max_chars=18
fi
