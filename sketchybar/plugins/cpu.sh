#!/bin/bash

cores=$(sysctl -n hw.logicalcpu 2>/dev/null || printf '1')
cpu=$(ps -A -o %cpu | awk -v cores="$cores" '{sum += $1} END {printf "%02d%%", sum / cores}')
top_process=$(ps -A -o %cpu= -o comm= | sort -nr | awk 'NR == 1 { n=$0; sub(/^[[:space:]]*[0-9.]+[[:space:]]+/, "", n); sub(/^.*\//, "", n); print n }')

percent=$((10#${cpu%%%}))
color=0xff38bdf8
label="$cpu"

if (( percent >= 80 )); then
    color=0xffef4444
    label="$cpu ${top_process:-proc}"
elif (( percent >= 55 )); then
    color=0xfff59e0b
    label="$cpu ${top_process:-proc}"
fi

sketchybar --set "$NAME" label="$label" icon.color="$color" label.max_chars=14
