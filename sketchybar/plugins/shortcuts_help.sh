#!/bin/bash

message="OmniWM — ventanas
⌥ + flechas: cambiar foco
⌥⇧ + flechas: reordenar ventanas (sin agrupar)
⌃⌥⌘ + flechas: mover ventana a otro monitor
⌥⌘F: expandir / restaurar (sin fullscreen nativo)

OmniWM — workspaces del monitor activo
⌥⌘ + 1–7: cambiar de workspace
⌥⌘⇧ + 1–7: mandar ventana al workspace
Vertical: 1 Grok · 2 Discord · 3 WhatsApp + Web
4 ChatGPT · 5 Spotify · 6 Herdr · 7 X

⌃ Control (o Caps Lock) · ⌥ Option · ⇧ Shift · ⌘ Command
Karabiner: Caps Lock tap Escape / hold Left Control
Ghostty: ver keymaps.md (docs/keymaps.md)
SketchyBar: click en el glyph dev abre ~/dev"

osascript -e "display dialog \"$message\" buttons {\"OK\"} default button \"OK\" with title \"Atajos del stack\"" >/dev/null 2>&1
