#!/bin/bash

message="Karabiner: Caps Lock tap Escape / hold Left Control
Ghostty: ver keymaps.md (docs/keymaps.md)
SketchyBar: click en el glyph dev abre ~/dev"

osascript -e "display dialog \"$message\" buttons {\"OK\"} default button \"OK\" with title \"Atajos del stack\"" >/dev/null 2>&1
