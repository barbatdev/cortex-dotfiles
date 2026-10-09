#!/bin/bash

message="Option + Command + H/J/K/L o flechas: foco ventanas
Option + Command + Shift + H/J/K/L o flechas: mover ventanas
Option + Command + 1..9: ir al space
Option + Command + Shift + 1..9: mover ventana al space
Option + Command + f: flotar/desflotar
Option + Command + Shift + f: zoom fullscreen
Option + Command + b: balancear layout
Option + Command + o: rotar layout
Option + Command + x/y: espejar layout
Option + Command + e: alternar split
Option + Command + Tab: space reciente
Option + Command + r: reset visual
Option + Command + Shift + r: recargar servicios"

osascript -e "display dialog \"$message\" buttons {\"OK\"} default button \"OK\" with title \"Atajos yabai/skhd\"" >/dev/null 2>&1
