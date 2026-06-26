#!/bin/bash

mode="workspace"

if command -v yabai >/dev/null 2>&1; then
    space_info="$(yabai -m query --spaces --space 2>/dev/null)"
    space="$(printf '%s' "$space_info" | sed -n 's/.*"label":"\([^"]*\)".*/\1/p')"
    if [[ -z "$space" ]]; then
        space="$(printf '%s' "$space_info" | sed -n 's/.*"index":\([0-9][0-9]*\).*/\1/p')"
    fi
    if [[ -n "$space" ]]; then
        mode="$space"
    fi
fi

sketchybar --set "$NAME" label="$mode"
