# dotfiles

Configuración local extraida de `cortex`: terminal, shell, prompt, helpers de AI CLI y herramientas de desarrollo para macOS.

## CI

GitHub Actions ejecuta un smoke check mínimo en pull requests y pushes a `main`: sintaxis Zsh/Bash, JSON con `jq`, TOML con `python3`/`tomllib`, y `./install.sh --check` cuando el instalador lo soporte.

## Stack

- **Terminal**: [Ghostty](https://ghostty.org/) y Alacritty
- **Shell**: Zsh nativo de macOS
- **Prompt**: [Starship](https://starship.rs/) — tema Gruvbox Dark
- **Multiplexor**: tmux + helpers de sesión
- **Barra macOS**: [SketchyBar](https://github.com/FelixKratz/SketchyBar) con tema Gruvbox
- **Window manager macOS**: [yabai](https://github.com/koekeishiya/yabai) + [skhd](https://github.com/koekeishiya/skhd) opcional y gradual
- **Keyboard remaps macOS**: [Karabiner-Elements](https://karabiner-elements.pqrs.org/) con profile `cortex`
- **Editor terminal**: Neovim basado en LazyVim/Gentleman.Dots con overlay RefactorIA
- **Ls**: [eza](https://github.com/eza-community/eza)
- **AI CLI UX**: Claude Code statusline, OpenCode helpers y cmux local/remoto
- **Workflow docs**: [cmux workflow](docs/cmux-workflow.md), [Herdr workflow](docs/herdr-workflow.md) y [keymaps prácticos](docs/keymaps.md)
- **Supply-chain guardrails**: defaults globales para `uv`, `npm`, `pnpm` y `bun`
- **Fuente**: FiraCode Nerd Font + variante custom RefactorIA

## Instalación

### macOS

```bash
mkdir -p ~/.cortex
git clone <repo-url> ~/.cortex/cortex-dotfiles
cd ~/.cortex/cortex-dotfiles
bash install.sh
```

Para auditar el entorno sin instalar paquetes ni modificar archivos:

```bash
bash install.sh --check
```

Para previsualizar lo que haría la instalación sin mutar archivos, instalar paquetes, arrancar servicios ni crear `local/env.zsh`:

```bash
bash install.sh --dry-run
```

El instalador macOS:
1. Instala dependencias via Homebrew (cmux, starship, tmux, lazygit, neovim, eza, sketchybar, yabai, skhd, Karabiner-Elements, FiraCode Nerd Font)
2. Hace backup de configs existentes con timestamp
3. Crea symlinks de los dotfiles y guardrails globales (`.npmrc`, `pnpm/rc`, `.bunfig.toml`, `uv.toml`)
4. Intenta seleccionar el profile `cortex` de Karabiner si `karabiner_cli` está disponible
5. Intenta arrancar/recargar `sketchybar`, `yabai` y `skhd` sin cortar la instalación si macOS requiere permisos
6. Crea `local/env.zsh` desde el template

## Estructura

```
dotfiles/
├── claude/                   # Claude Code statusline
├── docs/                     # Referencias operativas y keymaps
├── ghostty/                  # Config Ghostty, muxy legado y shaders
├── fonts/                    # Fuente RefactorIA y script de regeneración
├── npm/                      # Global npm defaults (~/.npmrc)
├── pnpm/                     # Global pnpm defaults (~/Library/Preferences/pnpm/rc)
├── bun/                      # Global bun defaults (~/.bunfig.toml)
├── uv/                       # Global uv defaults (~/.config/uv/uv.toml)
├── zsh/
│   ├── zshrc                 # Bootstrap: dotfiles primero, Cortex al final (~/.zshrc)
│   ├── cortex-dotfiles.zsh   # Entrypoint propio del profile de dotfiles
│   └── scripts/
│       ├── claude-helpers.zsh   # Integración Claude Code
│       ├── cmux-sidebar-refresh.sh # Metadata Cortex para cmux
│       ├── ssh-helpers.zsh      # cmux SSH y SSH convencional
│       ├── git-helpers.zsh      # Identidades Git y clone helpers
│       ├── tmux-helpers.zsh     # Helpers tmux
│       ├── worktree-helpers.zsh # Helpers git worktree
│       ├── screenshots.zsh      # Manejo de screenshots macOS
│       └── pcsoft-helpers.zsh   # Protección archivos PCSoft
├── tmux/                     # Config tmux
├── lazygit/                  # Config lazygit
├── karabiner/                # Config Karabiner-Elements (~/.config/karabiner/karabiner.json)
├── nvim/                     # Notas de configuración Neovim RefactorIA
├── sketchybar/               # Barra macOS y plugins
├── yabai/                    # Window manager macOS opcional
├── skhd/                     # Hotkeys macOS para yabai
├── starship/
│   └── starship.toml         # Prompt (~/.config/starship.toml)
├── local/
│   └── env.zsh.example       # Template de config local (gitignored)
└── install.sh
```

> Nota migración cmux: el path legacy `~/Library/Application Support/com.cmuxterm.app/config.ghostty` ya no está gestionado por estos dotfiles. Si todavía existe en tu máquina, podés borrarlo manualmente sin afectar la configuración actual.

## Boundary con Cortex

Este repo sigue siendo standalone: `install.sh` no requiere tener el repo `cortex` disponible y estos dotfiles deben poder instalarse por sí solos. El bootstrap carga primero `~/.config/cortex-dotfiles/shell/cortex-dotfiles.zsh` y, si existe, carga al final `~/.cortex/shell/cortex.zsh`, que pertenece a Cortex. Ambos fragments son opcionales y un error en uno no impide intentar cargar el otro. Cortex conserva el ownership de sus variables core; este repo solo define variables bajo el namespace `CORTEX_DOTFILES_*`.

Algunos artefactos viven acá temporalmente porque nacieron junto al setup personal, pero conceptualmente son propios del producto Cortex y no deberían tener a `cortex-dotfiles` como source of truth permanente:

- `opencode/themes/` — themes Cortex para OpenCode.
- `claude/themes/` — themes Cortex para Claude Code.
- `claude/statusline.sh` — statusline orientada a superficies Cortex.
- `docs/agent-state-v1.md` — contrato `cortex.agent_state.v1`.
- `scripts/check-agent-state.sh` — smoke check del contrato agent-state.
- `zsh/scripts/agent-state.sh` — bridge local para reportar estado de agentes.
- `zsh/scripts/postcompact-hook.sh` y `zsh/scripts/memsave-nudge.sh` — hooks ligados al workflow Cortex.

La migración se coordina en tres repos independientes: `cortex` define ownership de los artefactos product-owned, `cortex-dotfiles` conserva instalación/adaptación local, y `cortex-dots` sigue siendo un snapshot OSS-safe de dotfiles sin depender de `cortex`.

No borrar ni cambiar estos artefactos acá hasta que `cortex` tenga reemplazos validados y se decida qué queda como adaptación local.

Seguimiento: [cortex-dotfiles #31](https://github.com/barbatdev/cortex-dotfiles/issues/31), [cortex #1038](https://github.com/barbatdev/cortex/issues/1038), [cortex-dots #14](https://github.com/barbatdev/cortex-dots/issues/14).

## Especificaciones

- [Cortex Agent State v1](docs/agent-state-v1.md): contrato `cortex.agent_state.v1` para normalizar estados de agentes hacia Herdr, statuslines, SketchyBar y notificaciones.

## Comandos principales

| Comando | Descripción |
|---------|-------------|
| `gs`, `ga`, `gc`, `gp`, `gl` | Git shortcuts |
| `dev`, `barbat`, `cowork`, `personal`, `tools`, `worktrees` | Navegación rápida en `~/dev` |
| `work`, `work-apis`, `work-mobile`, `work-webs`, `work-pcsoft` | Navegación rápida de trabajo |
| `dotfiles` | Navegación rápida al repo de dotfiles |
| `cc [path]` | Abrir Claude Code |
| `oc [path]` | Abrir OpenCode |
| `ccclip <files>` | Copiar código al clipboard |
| `tcc`, `tdev`, `ta`, `tn`, `tl`, `tk` | Helpers tmux (`tcc` abre Claude Code en tmux) |
| `wtadd`, `wtlist`, `wtremove` | Helpers de git worktrees |
| `sshx`, `sshc`, `sshx-doctor` | cmux SSH persistente, SSH convencional y diagnóstico |
| `cortex.agent_state.v1`, `agent-state` | Reportar/listar estado local de agentes Cortex y, dentro de Herdr, actualizar el pane actual |
| `ss [n]` | Listar últimos screenshots |
| `last [-c\|-o]` | Último screenshot |
| `ll`, `la`, `lt` | Listar archivos (eza) |
| `ep` | Editar este profile |
| `reload` | Recargar zsh |
| `refactoria` | Mostrar el logo RefactorIA en Braille Unicode |
| `help-profile` | Ver todos los comandos |

## Personalización

Editá `local/env.zsh` (gitignored) para configurar:
- `SCREENSHOTS_DIR` — directorio de screenshots
- `WORKSPACE_DIR` — directorio raíz de tus proyectos
- `CORTEX_DOTFILES_DIR` — repo dotfiles, por defecto `$BARBATDEV_DIR/cortex/cortex-dotfiles`
- `CORTEX_DOTFILES_SHELL_ENTRYPOINT` — override del entrypoint propio, por defecto `~/.config/cortex-dotfiles/shell/cortex-dotfiles.zsh`
- `CORTEX_DOTFILES_MULTIPLEXER` — fallback standalone para helpers, por defecto `cmux`; `CORTEX_MULTIPLEXER` de Cortex tiene precedencia
- `OPENCODE_DEFAULT_FLAGS` — flags por defecto para `oc`
- `INNIT_DIR` y overrides `INNIT_*_DIR` — navegación rápida de subdirectorios
- Aliases y paths personales

## Herdr remoto

Referencia completa: [Herdr workflow](docs/herdr-workflow.md). Atajos prácticos: [keymaps](docs/keymaps.md).

Usá `hremote` desde tu terminal local en macOS. No hagas `ssh` primero y después intentes levantar `herdr` dentro de esa sesión remota.

- Para pegar una imagen del clipboard local en la terminal remota, usá `Ctrl+V` por defecto (no `Cmd+V`).
- `herdr --remote` puentea ese pegado copiando la imagen a un archivo temporal remoto y pegando el path resultante en la shell remota.
- Una sesión SSH normal no puede leer el clipboard del escritorio local de macOS, así que ese flujo depende de Herdr corriendo del lado local.
- Para archivos que no sean imágenes del clipboard, puede seguir haciendo falta un fallback separado de transferencia.

## SketchyBar

La config macOS enlaza `sketchybar/` en `~/.config/sketchybar`. El diseño es sobrio, notch-safe y usa la paleta dark/green de InnIT.

Layout activo:

| Pantalla | Uso | Layout |
|------|-----|--------|
| Mac Retina (`display=1`) | apps generales: Discord, WhatsApp, Mail, Postman, Zen Browser | app activa + network, volumen, calendario, hora, batería |
| ViewSonic vertical (`display=2`) | auxiliar/random, Ghostty/Herdr y Claude de formato vertical | brand + panel/spaces + app activa; derecha: RAM + CPU + hora |
| LG Ultrawide (`display=3`) | mixto: Ghostty/Herdr, Claude, ChatGPT, Obsidian | brand + panel/spaces + app activa; derecha: RAM + CPU + hora |
| 4K derecho (`display=4`) | Ghostty/Herdr exclusivo | brand + panel/spaces + app activa; derecha: RAM + CPU + hora |

El centro queda libre para evitar el notch y reducir ruido visual.

Interacciones:

| Item | Acción |
|------|--------|
| Glyph RefactorIA | abre `~/dev` |
| Spaces | enfocan el space si `yabai` está corriendo |
| Volumen | mute/unmute |
| Batería | abre Battery Settings |
| Fecha/hora | abre Calendar |

La barra asume Mac con notch y varios monitores: el centro queda libre y evita widgets de contexto remoto (`git`, issue/PR, SDD, brains, timer), porque el trabajo operativo corre en Herdr remoto.

El layout cambia automáticamente al recargar SketchyBar: con un solo display, el Retina mantiene los indicadores de estado útiles; con varios displays, el Retina queda liviano y el layout completo se mueve al externo disponible.

Si macOS deja monitores externos como `Online` aunque estén desconectados, se puede forzar perfil con:

```bash
~/.config/sketchybar/sketchybar-profile.sh portable
~/.config/sketchybar/sketchybar-profile.sh office
~/.config/sketchybar/sketchybar-profile.sh auto
```

La separación global de ventanas queda desactivada en yabai (`top_padding=0`, `bottom_padding=0`, `left_padding=0`, `right_padding=0`, `window_gap=0`) para evitar márgenes persistentes después de reiniciar.

El instalador intenta activarla automáticamente. Si macOS bloquea el servicio o querés hacerlo manualmente:

```bash
brew services start sketchybar
```

Para recargar cambios manualmente:

```bash
sketchybar --reload
```

## yabai + skhd

Atajos resumidos junto al resto del stack: [keymaps](docs/keymaps.md).

La config incluida es gradual y no usa scripting addition: no requiere desactivar SIP. Sirve para acostumbrarse al tiling y navegación por teclado sin cambiar partes sensibles de macOS.

El instalador crea symlinks en ambas rutas de configuración: `~/.config/yabai/yabairc` y `~/.yabairc` para yabai, `~/.config/skhd/skhdrc` y `~/.skhdrc` para skhd. Se mantienen las rutas legacy porque los launch services de yabai/skhd leen esas ubicaciones por defecto.

Decisiones:

| Tema | Decisión |
|------|----------|
| Leader | `Option + Command` |
| Scripting addition | No se usa |
| Raycast | Evitar shortcuts con `Option + Command` para reducir colisiones |
| Apps flotantes | System Settings, Calculator, Activity Monitor y diálogos de Finder |
| SketchyBar | Los spaces de la barra usan `yabai` si está disponible |

El instalador intenta arrancar o recargar estos servicios automáticamente después de enlazar la configuración. Activación manual de fallback:

```bash
yabai --start-service
skhd --start-service
```

Para detenerlos:

```bash
yabai --stop-service
skhd --stop-service
```

Si macOS bloquea los servicios, habilitá permisos en:

```text
System Settings → Privacy & Security → Accessibility
```

Binarios a permitir:

```text
/opt/homebrew/bin/yabai
/opt/homebrew/bin/skhd
```

Atajos principales (`option + command`):

| Atajo | Acción |
|-------|--------|
| `Option + Command + Left/Down/Up/Right` | Focus izquierda/abajo/arriba/derecha |
| `Option + Command + Shift + Left/Down/Up/Right` | Mover ventana en el layout |
| `Option + Command + 1..9` | Ir al space |
| `Option + Command + Shift + 1..9` | Mover ventana al space y seguirla |
| `Option + Command + f` | Flotar/desflotar ventana |
| `Option + Command + b` | Balancear layout |
| `Option + Command + r` | Resetear gap a cero + balance + recargar SketchyBar |
| `Option + Command + /` | Mostrar ayuda de atajos |
| `Option + Command + Shift + r` | Recargar yabai/skhd/sketchybar |

Notas de uso:

- `Option` es la tecla que macOS también llama `Alt`.
- El bloque `dev` de SketchyBar también abre la ayuda de atajos con click.
- Algunos comandos no hacen nada si no hay una ventana gestionada por `yabai` o si no existe una ventana vecina en esa dirección.
- Si Raycast usa el mismo shortcut, deshabilitá ese hotkey en Raycast o cambialo para dejar `Option + Command` a `skhd`.
- Para recargar cambios manualmente: `skhd --reload && yabai --restart-service && sketchybar --reload`.

## Karabiner-Elements

La config enlaza `karabiner/karabiner.json` en `~/.config/karabiner/karabiner.json` y define un profile default llamado `cortex`.

Remap incluido:

| Tecla | Acción |
|-------|--------|
| `Caps Lock` tap | `Escape` |
| `Caps Lock` hold | `Left Control` |
| `Right Command` | `Delete backward` |

El instalador instala `karabiner-elements` via Homebrew cask si no encuentra `karabiner_cli` ni la app, hace backup del JSON existente y crea el symlink. Si `karabiner_cli` está disponible, intenta seleccionar el profile `cortex` como best-effort.

macOS puede requerir permisos en:

```text
System Settings → Privacy & Security → Input Monitoring
System Settings → Privacy & Security → Accessibility
```

Después de instalar o cambiar permisos, puede hacer falta abrir o reiniciar Karabiner-Elements para que cargue la config versionada.

## Fuente RefactorIA

El prompt usa una variante local de FiraCode Nerd Font Mono con el glyph de la barba de RefactorIA en el Private Use Area.

| Dato | Valor |
|------|-------|
| Family | `FiraCode Nerd Font Mono Beard` |
| Archivo instalado | `~/Library/Fonts/FiraCodeNerdFontMonoBeard-Reg.ttf` |
| Codepoint | `U+F0F00` |
| Glyph test | `python3 -c 'print("\U000F0F00")'` |

La config de Starship usa este glyph PUA directamente. Si la terminal no tiene seleccionada `FiraCode Nerd Font Mono Beard`, el prompt puede mostrar un cuadrado/tofu en lugar de la barba. En macOS, `install.sh` instala la fuente y deja configurado Ghostty con esa family.

Para regenerar la fuente:

```bash
mkdir -p ~/Downloads/refactoria/build
magick ~/Downloads/refactoria/RefactorIA.png -threshold 50% -negate ~/Downloads/refactoria/build/refactoria.bmp
potrace ~/Downloads/refactoria/build/refactoria.bmp -s -o ~/Downloads/refactoria/build/refactoria.svg
fontforge -script fonts/patch_beard.py \
  --font ~/Library/Fonts/FiraCodeNerdFontMono-Regular.ttf \
  --svg ~/Downloads/refactoria/build/refactoria.svg \
  --output-dir ~/Downloads/refactoria/build
cp ~/Downloads/refactoria/build/FiraCodeNerdFontMonoBeard-Reg.ttf ~/Library/Fonts/
```

One-liner para renderizar el glyph con Pillow:

```bash
python3 - <<'PY'
from PIL import Image, ImageDraw, ImageFont
font = ImageFont.truetype('~/Library/Fonts/FiraCodeNerdFontMonoBeard-Reg.ttf', 64)
img = Image.new('RGB', (128, 128), 'black')
draw = ImageDraw.Draw(img)
draw.text((32, 24), '\U000F0F00', font=font, fill='white')
img.save('/tmp/refactoria-glyph.png')
PY
```

## Marca RefactorIA en terminal

El comando `refactoria` imprime una versión Braille Unicode del logo. Es intencionalmente bajo demanda para no meter ruido visual en cada shell nueva.

```bash
refactoria
```

Uso recomendado:
- screenshots o demos donde conviene una marca visual sin depender de imágenes
- intros manuales antes de grabar o compartir una terminal
- banners puntuales en scripts propios, siempre que no tapen output útil

No usarlo como banner automático del shell por defecto. En sesiones de trabajo largas, el prompt con el glyph `󰼀` ya cumple la función de marca permanente con menos ruido.

## Guardrails globales

El setup instala estas protecciones globales para reducir riesgo de supply-chain:

- `~/.npmrc`
  - `min-release-age=7`
  - `ignore-scripts=true`
- `~/Library/Preferences/pnpm/rc`
  - `minimum-release-age=10080` (7 días en minutos)
  - `strict-dep-builds=true`
  - `block-exotic-subdeps=true`
  - `trust-policy=no-downgrade`
- `~/.bunfig.toml`
  - `minimumReleaseAge = 604800`
- `~/.config/uv/uv.toml`
  - `exclude-newer = "7 days"`

Además, la política operativa recomendada es:

- evitar upgrades accidentales o implícitos de dependencias
- preferir versiones pinneadas y lockfiles cuando el proyecto lo justifique
- evitar `latest` y ejecuciones runtime no revisadas salvo necesidad explícita
- hacer upgrades de dependencias en cambios/PRs dedicados, no mezclados con features
