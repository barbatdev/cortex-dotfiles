#!/bin/bash

# RefactorIA semantic colors; connected network status is neutral, disconnected stays warning.
TEXT=0xffffffff
NORMAL=0xfff2effa
WARNING=0xffffc857

color=$NORMAL
icon="󰈀"
label="net"

if scutil --nc list 2>/dev/null | grep -q 'Connected'; then
    icon="󰖂"
    label="vpn"
elif [[ -n "${CORTEX_LAN_PROBE_HOST:-}" ]] && nc -z -G 1 "$CORTEX_LAN_PROBE_HOST" "${CORTEX_LAN_PROBE_PORT:-5432}" >/dev/null 2>&1; then
    icon="󰈀"
    label="lan ai"
else
    service=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2; exit }')
    if [[ "$service" == en* ]]; then
        icon="󰈀"
        label="$service"
        color=$NORMAL
    else
        wifi_device=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/ {getline; print $2; exit}')
        ssid=$(networksetup -getairportnetwork "$wifi_device" 2>/dev/null | sed 's/^Current Wi-Fi Network: //')
        icon="󰖩"
        label="${ssid:-offline}"
        color=$WARNING
    fi
fi

sketchybar --set "$NAME" icon="$icon" label="$label" icon.color="$color" label.color="$TEXT" label.max_chars=14
