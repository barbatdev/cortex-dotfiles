#!/bin/bash

# RefactorIA semantic colors; normal resource status uses the blue info icon.
TEXT=0xffffffff
NORMAL=0xff8cc8ff
WARNING=0xffffc857
ERROR=0xffff6b8a

cores=$(sysctl -n hw.logicalcpu 2>/dev/null || printf '1')
cpu=$(ps -A -o %cpu | awk -v cores="$cores" '{sum += $1} END {printf "%02d%%", sum / cores}')
top_process=$(ps -A -o %cpu= -o comm= | sort -nr | awk 'NR == 1 { n=$0; sub(/^[[:space:]]*[0-9.]+[[:space:]]+/, "", n); sub(/^.*\//, "", n); print n }')

percent=$((10#${cpu%%%}))
color=$NORMAL
label="$cpu"

if (( percent >= 80 )); then
    color=$ERROR
    label="$cpu ${top_process:-proc}"
elif (( percent >= 55 )); then
    color=$WARNING
    label="$cpu ${top_process:-proc}"
fi

sketchybar --set "$NAME" label="$label" icon.color="$color" label.color="$TEXT" label.max_chars=14
