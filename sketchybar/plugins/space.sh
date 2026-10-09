#!/bin/bash

# Selected spaces use the raised surface with a readable brand outline; inactive spaces stay neutral.
if [[ "$SELECTED" == "true" ]]; then
    sketchybar --animate tanh 10 --set "$NAME" \
        icon.color=0xffffffff \
        background.color=0xff2c2144 \
        background.border_color=0xffa477ff \
        background.border_width=1
else
    sketchybar --animate tanh 10 --set "$NAME" \
        icon.color=0xffebebeb \
        background.color=0xaa2c2144 \
        background.border_color=0x00000000 \
        background.border_width=0
fi
