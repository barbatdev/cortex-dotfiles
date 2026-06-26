#!/bin/bash

page_size=$(vm_stat | awk '/page size of/ {gsub("[^0-9]", "", $8); print $8}')
pages_anonymous=$(vm_stat | awk '/Anonymous pages/ {gsub("\\.", "", $3); print $3}')
total_bytes=$(sysctl -n hw.memsize)

if (( page_size == 0 || total_bytes == 0 )); then
    sketchybar --set "$NAME" label="--"
    exit 0
fi

# Match the user's mental model: memory currently held by apps, not macOS file
# cache, inactive pages, wired kernel memory, or compressor footprint.
app_bytes=$((pages_anonymous * page_size))
percent=$((app_bytes * 100 / total_bytes))
swap_used_mb=$(sysctl vm.swapusage | awk '{ for (i = 1; i <= NF; i++) if ($i == "used") { gsub("M", "", $(i + 2)); printf "%d", $(i + 2) } }')
top_process=$(ps -A -o rss= -o comm= | sort -nr | awk 'NR == 1 { n=$0; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, "", n); sub(/^.*\//, "", n); print n }')

color=0xff38bdf8
label="${percent}%"

if (( percent >= 75 || swap_used_mb >= 4096 )); then
    color=0xffef4444
    label="${percent}% ${top_process:-proc}"
elif (( percent >= 60 || swap_used_mb >= 1024 )); then
    color=0xfff59e0b
    if (( swap_used_mb >= 1024 )); then
        label="${percent}% swp"
    else
        label="${percent}% ${top_process:-proc}"
    fi
fi

sketchybar --set "$NAME" label="$label" icon.color="$color" label.max_chars=14
