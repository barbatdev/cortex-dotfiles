# TODO — Dotfiles improvements

Mejoras identificadas en dotfiles externos de referencia.

---

## Alta prioridad

- [x] **Glyph custom RefactorIA para Nerd Font** — `FiraCode Nerd Font Mono Beard` versionado en `fonts/FiraCodeNerdFontMonoBeard-Reg.ttf`, instalado en `~/Library/Fonts/FiraCodeNerdFontMonoBeard-Reg.ttf`, codepoint `U+F0F00`, script regenerable en `fonts/patch_beard.py`, Ghostty y Starship configurados.
- [x] **Statusline custom para Claude Code** — script que muestra barra visual de uso del contexto (verde/amarillo/rojo), modelo activo, rama git y porcentaje exacto.
- [x] **Sesión flotante Alt+G en tmux** — popup flotante sobre cualquier layout.
- [x] **tmux-resurrect** — guarda y restaura sesiones tmux al reiniciar. `Prefix+Ctrl+S` / `Prefix+Ctrl+R`.

## Media prioridad

- [x] **SketchyBar macOS** — barra versionada en `sketchybar/`, instalada por Homebrew y enlazada a `~/.config/sketchybar`; incluye espacios, app activa, reloj y calendario.
- [x] **Issues #327/#328 — servicios y atajos yabai/skhd** — `install.sh` intenta arrancar SketchyBar/yabai/skhd sin cortar por permisos macOS; focus/move usan flechas en skhd, ayuda y README.
- [x] **Karabiner-Elements macOS** — config versionada en `karabiner/karabiner.json`, instalada por Homebrew cask y enlazada a `~/.config/karabiner/karabiner.json`; profile `cortex` con Caps Lock tap Escape / hold Left Control.
- [x] **`macos-option-as-alt = left` en Ghostty** — Alt izquierdo como meta key, Alt derecho para tildes y ñ.
- [x] **`right_format` en Starship** — cmd_duration y time alineados al extremo derecho.
- [x] **`atuin`** — historial de zsh con SQLite y TUI avanzada en Ctrl+R.

## Baja prioridad

- [x] **Shaders de cursor en Ghostty** — 4 shaders disponibles en `ghostty/shaders/`. Activo: cursor_smear_gentleman. Para cambiar: editar `custom-shader` en ghostty/config.
- [x] **`tmux-which-key`** — muestra keybindings al presionar el prefix.
- [x] **`window-padding-balance = true` en Ghostty** — padding balanceado en splits.

---

## Mejoras de memoria — inspiradas en Engram v1.10.5

### Alta prioridad

- [x] **Nudge de 15 minutos sin mem_save** — Hook `UserPromptSubmit` que revisa el timestamp de la última observación en dev-memory. Si pasaron +15 min y la sesión tiene +5 min de antigüedad, inyecta recordatorio para guardar contexto. Evita pérdida de decisiones en sesiones largas de implementación.

### Media prioridad

- [x] **PostCompact con orden explícito** — Mejorar el hook PostCompact actual (genérico) para que instruya el orden exacto: `mem_session_summary` primero → `mem_context` después, con el nombre del proyecto interpolado. Más determinístico que el mensaje actual.

- [x] **detect_project() con git remote** — Derivar el nombre del proyecto desde `git remote get-url origin` en vez de dirname. Más robusto en worktrees y monorepos donde el nombre del directorio no refleja el proyecto real.

---

## Worktrees — integración natural con Claude

- [x] **Worktree helpers zsh + cmux** — `wtadd`/`wtlist`/`wtremove` en `worktree-helpers.zsh`. Mecánica pura: crear directorio hermano, detectar repos PCSoft via `is-pcsoft-forbidden`, abrir workspace cmux automáticamente. Los comandos son la infraestructura, no el punto de entrada al usuario.

- [x] **Regla de evaluación proactiva en claude-config** — Claude evalúa si worktrees convienen y los sugiere/implementa sin que el usuario lo pida. Triggers: "hay un bug urgente y estoy en medio de algo", feature branch larga + hotfix simultáneo, "no quiero perder contexto pero necesito cambiar de rama". Si el repo es PCSoft → nunca sugerir. Si es no-PCSoft y hay conflicto de contexto → proponer `wtadd` + nuevo workspace cmux directamente.
