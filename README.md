# dotfiles

Configuración local extraida de `cortex`: terminal, shell, prompt, helpers de AI CLI y herramientas de desarrollo para macOS.

## Stack

- **Terminal**: [Ghostty](https://ghostty.org/)
- **Shell**: Zsh nativo de macOS
- **Prompt**: [Starship](https://starship.rs/) — tema Gruvbox Dark
- **Multiplexor**: [Herdr](https://herdr.dev/) para sesiones locales/remotas persistentes
- **Barra macOS**: [SketchyBar](https://github.com/FelixKratz/SketchyBar) con tema Gruvbox
- **Window manager macOS**: [yabai](https://github.com/koekeishiya/yabai) + [skhd](https://github.com/koekeishiya/skhd) opcional y gradual
- **Keyboard remaps macOS**: [Karabiner-Elements](https://karabiner-elements.pqrs.org/) con profile `cortex`
- **Editor terminal**: [micro](https://micro-editor.github.io/)
- **Editor principal**: Neovim basado en LazyVim/Gentleman.Dots con overlay RefactorIA
- **Ls**: [eza](https://github.com/eza-community/eza)
- **AI CLI UX**: Claude Code statusline, OpenCode helpers y sesiones Herdr por repo
- **Supply-chain guardrails**: defaults globales para `uv`, `npm`, `pnpm` y `bun`
- **Fuente**: FiraCode Nerd Font + variante custom RefactorIA

## Instalación

### macOS

```bash
git clone <repo-url> ~/dev/personal/cortex-dotfiles
cd ~/dev/personal/cortex-dotfiles
bash install.sh
```

El instalador macOS:
1. Instala dependencias via Homebrew (starship, herdr, mosh, lazygit, micro, eza, sketchybar, yabai, skhd, Karabiner-Elements, FiraCode Nerd Font)
2. Hace backup de configs existentes con timestamp
3. Crea symlinks de los dotfiles y guardrails globales (`.npmrc`, `pnpm/rc`, `.bunfig.toml`, `uv.toml`)
4. Intenta seleccionar el profile `cortex` de Karabiner si `karabiner_cli` está disponible
5. Intenta arrancar/recargar `sketchybar`, `yabai` y `skhd` sin cortar la instalación si macOS requiere permisos
6. Crea `local/env.zsh` desde el template

## Estructura

```
dotfiles/
├── claude/                   # Claude Code statusline
├── ghostty/                  # Config Ghostty y shaders
├── fonts/                    # Fuente RefactorIA y script de regeneración
├── herdr/                    # Config Herdr
├── npm/                      # Global npm defaults (~/.npmrc)
├── pnpm/                     # Global pnpm defaults (~/Library/Preferences/pnpm/rc)
├── bun/                      # Global bun defaults (~/.bunfig.toml)
├── uv/                       # Global uv defaults (~/.config/uv/uv.toml)
├── zsh/
│   ├── zshrc                 # Profile principal (~/.zshrc)
│   └── scripts/
│       ├── claude-helpers.zsh   # Integración Claude Code
│       ├── git-helpers.zsh      # Identidades Git y clone helpers
│       ├── ssh-helpers.zsh      # SSH/Mosh con contexto visible
│       ├── herdr-helpers.zsh    # Helpers Herdr para sesiones y orientación
│       ├── worktree-helpers.zsh # Helpers git worktree
│       ├── screenshots.zsh      # Manejo de screenshots macOS
│       └── pcsoft-helpers.zsh   # Protección archivos PCSoft
├── lazygit/                  # Config lazygit
├── karabiner/                # Config Karabiner-Elements (~/.config/karabiner/karabiner.json)
├── micro/                    # Settings y themes de micro
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

## Comandos principales

| Comando | Descripción |
|---------|-------------|
| `gs`, `ga`, `gc`, `gp`, `gl` | Git shortcuts |
| `dev`, `barbat`, `cowork`, `personal`, `tools`, `worktrees` | Navegación rápida en `~/dev` |
| `work`, `work-apis`, `work-mobile`, `work-webs`, `work-pcsoft` | Navegación rápida de trabajo |
| `cortex`, `dotfiles` | Navegación rápida al repo `cortex` y sus dotfiles |
| `cc [path]` | Abrir Claude Code |
| `oc [path]` | Abrir OpenCode |
| `hhere`, `hmain` | Volver a la sesión Herdr principal del repo/branch |
| `hnew [path]` | Crear sesión Herdr independiente con timestamp |
| `hrole <rol> [path]` | Entrar/crear sesión Herdr por rol operativo |
| `hfocus`, `hside`, `hscratch` | Sesiones Herdr por rol para foco, lateral o scratch |
| `hremote <host> [session]` | Attach remoto con `herdr --remote` |
| `hname [label]` | Nombrar el pane Herdr actual |
| `moshx <host> [remote-path]` | Mosh al host; con path entra a ese directorio remoto |
| `moshx-doctor <host>` | Verifica `mosh-server`, `herdr`, `git` y `sh` en el host remoto |
| `sshx <host>` | SSH directo con contexto visible |
| `sshc <host>` | SSH directo con host visible en prompt |
| `whereami` | Mostrar host, cwd, repo, sesión y SSH |
| `ccclip <files>` | Copiar código al clipboard |
| `wtadd`, `wtlist`, `wtremove` | Helpers de git worktrees |
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
- `OPENCODE_DEFAULT_FLAGS` — flags por defecto para `oc`
- `CORTEX_MULTIPLEXER=herdr` — marca Herdr como multiplexor operativo para prompt/helpers
- `INNIT_DIR` y overrides `INNIT_*_DIR` — navegación rápida de subdirectorios
- Aliases y paths personales

## Herdr remoto

Para SSH/remoto, el modelo recomendado es Herdr. Usá sesiones nombradas para separar tableros persistentes, workspaces por repo, tabs por objetivo y panes por agente/proceso:

```bash
hremote agent-dev-01 main
hhere ~/dev/personal/cortex
hfocus ~/dev/personal/cortex
hside ~/dev/personal/cortex
```

Si necesitás diagnosticar dependencias:

```bash
moshx-doctor agent-dev-01
```

Comportamiento:

- `hhere [path]` y `hmain [path]` nombran la sesión principal por host + repo + branch, para reattach exacto.
- `hnew [path]` crea otra sesión independiente del mismo repo/branch con timestamp corto.
- `hrole <rol> [path]`, `hfocus [path]`, `hside [path]` y `hscratch [path]` crean/entran a sesiones independientes por intención operativa, no por monitor físico.
- Si ya estás dentro de Herdr, esos helpers no intentan abrir Herdr anidado: crean o enfocan un workspace con el mismo nombre dentro de la sesión actual.
- `hremote <host> [session]` usa el bridge remoto de Herdr.
- `hname [label]` evita panes anónimos en el sidepanel.
- `cc [path]`, `ccb [path]`, `oc [path]` y `ocb [path]` ejecutan el agente en el pane actual; Herdr provee persistencia.
- Herdr también expone CLI scriptable para `workspace`, `tab`, `pane`, `agent`, `worktree`, `wait` e `integration`; los helpers solo cubren el flujo muscular diario.
- `install.sh` asegura `herdr integration install claude` y `herdr integration install opencode` en la máquina local. En hosts remotos, corré esas mismas integrations una vez por host.
- Prompt Starship marca `herdr` cuando `CORTEX_MULTIPLEXER=herdr`.
- `whereami` muestra ubicación completa sin depender de la UI.

## SketchyBar

La config macOS enlaza `sketchybar/` en `~/.config/sketchybar`. El diseño es sobrio, notch-safe y usa la paleta dark/green de InnIT.

Layout activo:

| Pantalla | Uso | Layout |
|------|-----|--------|
| Mac Retina (`display=1`) | apps generales: Discord, WhatsApp, Mail, Postman, Zen Browser | app activa + network, volumen, calendario, hora, batería |
| ViewSonic vertical (`display=2`) | auxiliar/random, Ghostty/Herdr y Claude de formato vertical | brand + panel/spaces + app activa + git + issue/PR + SDD + brains + timer; derecha: RAM + CPU + hora |
| LG Ultrawide (`display=3`) | mixto: Ghostty/Herdr, Claude, ChatGPT, Obsidian | brand + panel/spaces + app activa + git + issue/PR + SDD + brains + timer; derecha: RAM + CPU + hora |
| 4K derecho (`display=4`) | Ghostty/Herdr exclusivo | brand + panel/spaces + app activa + git + issue/PR + SDD + brains + timer; derecha: RAM + CPU + hora |

El centro queda libre para evitar el notch y reducir ruido visual.

Interacciones:

| Item | Acción |
|------|--------|
| Glyph RefactorIA | abre `~/dev` |
| Spaces | enfocan el space si `yabai` está corriendo |
| Volumen | mute/unmute |
| Batería | abre Battery Settings |
| Fecha/hora | abre Calendar |

La barra asume Mac con notch y varios monitores: el centro queda libre y los items operativos se mantienen en los laterales. Los items de contexto (`git`, issue/PR, SDD y timer) se actualizan con un agregador liviano que lee `${XDG_CACHE_HOME:-~/.cache}/cortex/active-workspace`. `SKETCHYBAR_WORKSPACE` permite forzar un repo específico.

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
