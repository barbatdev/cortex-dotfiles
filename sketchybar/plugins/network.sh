#!/bin/bash

color=0xff3fb950
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
        color=0xff94a3b8
    else
        wifi_device=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/ {getline; print $2; exit}')
        ssid=$(networksetup -getairportnetwork "$wifi_device" 2>/dev/null | sed 's/^Current Wi-Fi Network: //')
        icon="󰖩"
        label="${ssid:-offline}"
        color=0xfff59e0b
    fi
fi

sketchybar --set "$NAME" icon="$icon" label="$label" icon.color="$color" label.max_chars=14
