# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repositorio

Dotfiles para macOS: configuración de Ghostty + Zsh + Starship. El instalador crea symlinks desde el directorio del repo hacia las ubicaciones estándar del sistema.

## Instalación y testing

```bash
# Instalar dotfiles (crea symlinks + instala dependencias via Homebrew)
./install.sh

# Medir load time del profile zsh
time zsh -i -c exit

# Verificar que los symlinks están correctos
ls -la ~/.zshrc ~/.config/starship.toml ~/.config/ghostty/config
```

No hay tests automatizados. La validación es manual: recargar la shell con `source ~/.zshrc` o `reload` y verificar que los comandos funcionen.

## Estructura y arquitectura

```
dotfiles/
├── zsh/
│   ├── zshrc                 # Profile principal → symlink a ~/.zshrc
│   └── scripts/              # Scripts sourced desde zshrc
│       ├── claude-helpers.zsh   # cc, ccx, ccd, ccclip
│       ├── git-helpers.zsh      # git-workdev, git-personaldev, git-whoami, clone-*
│       ├── pcsoft-helpers.zsh   # is-pcsoft-forbidden, is-pcsoft-editable
│       ├── screenshots.zsh      # ss, last, ssd, imgclip
│       └── tmux-helpers.zsh     # ta, tn, tk, tl, tdev
├── starship/starship.toml    # Prompt Gruvbox Dark → symlink a ~/.config/starship.toml
├── ghostty/config            # Terminal → symlink a ~/.config/ghostty/config
├── tmux/tmux.conf            # Multiplexor → symlink a ~/.tmux.conf
├── local/
│   └── env.zsh.example       # Template para local/env.zsh (gitignored)
└── install.sh                # Instalador
```

**Flujo de carga del zshrc:** Las secciones están separadas por `#region`/`#endregion`. El orden importa: Brew → PATH → Zsh options → Editor → Env vars → Aliases → Source scripts → Local overrides → Starship → Welcome.

**`local/env.zsh`** está gitignored y contiene paths personales, tokens y overrides de variables de entorno (`SCREENSHOTS_DIR`, `WORKSPACE_DIR`, `WORK_PROJECTS_DIR`). Se genera desde `env.zsh.example` en la primera instalación.

## Múltiples identidades GitHub

El repositorio maneja dos cuentas de GitHub con SSH host aliases:
- `github-workdev` → cuenta de trabajo/empresa (configurar con tu email de empresa)
- `github-personaldev` → cuenta personal (configurar con tu email personal)

Los helpers en `git-helpers.zsh` configuran la identidad local del repo Y actualizan el remote URL para usar el alias SSH correcto. Cuando se agregan nuevas funciones relacionadas con identidades, seguir el mismo patrón.

## Convenciones al editar

- Los scripts `.zsh` usan `#region`/`#endregion` para agrupar secciones lógicas.
- Cada función pública en los scripts debe tener un comentario explicando su uso.
- Variables de entorno con defaults se definen como `${VAR:-default}` para permitir override desde `local/env.zsh`.
- `install.sh` usa `set -e` y hace backup de configs existentes antes de crear symlinks — mantener este comportamiento al agregar nuevas configs.

## Agregar una nueva configuración

1. Crear el archivo de config en su directorio (`nombre-herramienta/config`)
2. Agregar backup + symlink en `install.sh` siguiendo el patrón existente
3. Actualizar el README.md con la nueva entrada en la tabla de estructura
