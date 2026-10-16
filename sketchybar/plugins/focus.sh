#!/bin/bash

mode="workspace"

# macOS native space label: Mission Control groups are not exposed to scripts
# without a window manager, so the item keeps the static workspace label.
sketchybar --set "$NAME" label="$mode"
