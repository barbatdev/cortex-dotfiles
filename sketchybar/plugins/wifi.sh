#!/bin/bash

wifi_device=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/ {getline; print $2; exit}')

if [[ -z "$wifi_device" ]]; then
    sketchybar --set "$NAME" icon="󰖪" label="no wifi" icon.color=0xffff5555
    exit 0
fi

ssid=$(networksetup -getairportnetwork "$wifi_device" 2>/dev/null | sed 's/^Current Wi-Fi Network: //')

if [[ -z "$ssid" || "$ssid" == *"not associated"* || "$ssid" == *"You are not associated"* ]]; then
    sketchybar --set "$NAME" icon="󰖪" label="offline" icon.color=0xffff5555
else
    sketchybar --set "$NAME" icon="󰖩" label="$ssid" icon.color=0xff5fd787 label.max_chars=18
fi
