#!/bin/bash

if [[ "$SELECTED" == "true" ]]; then
    sketchybar --animate tanh 10 --set "$NAME" \
        icon.color=0xff08110c \
        background.color=0xff3fb950
else
    sketchybar --animate tanh 10 --set "$NAME" \
        icon.color=0xff94a3b8 \
        background.color=0xaa18222c
fi
