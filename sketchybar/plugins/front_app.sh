#!/bin/bash

if [[ -n "$INFO" ]]; then
    sketchybar --set "$NAME" label="$INFO"
else
    front_app=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)
    sketchybar --set "$NAME" label="${front_app:-Desktop}"
fi
