#!/bin/bash

if [[ -n "$INFO" ]]; then
    sketchybar --set "$NAME" label="$INFO"
else
    front_app=$(yabai -m query --windows --window 2>/dev/null | awk -F'"' '/"app":/ { print $4; exit }')
    sketchybar --set "$NAME" label="${front_app:-Desktop}"
fi
