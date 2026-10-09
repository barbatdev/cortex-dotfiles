# Neovim

> **Estado actual observado (2026-09-24):** La configuración activa vive en
> `~/.config/nvim`. Es un directorio regular administrado por el host, no un
> symlink de este repo. Esta nota documenta esa observación; no convierte la
> configuración del host en source of truth versionado.

## Estado visual auditado

- El plugin spec del host selecciona/configura `gentleman-kanagawa-blur`
  (Gentleman Kanagawa Blur); no se verificó `:colorscheme` en runtime.
- El plugin spec de Lualine referencia el mismo theme en
  `~/.config/nvim/lua/plugins/ui.lua`.
- La selección del colorscheme está en
  `~/.config/nvim/lua/plugins/colorscheme.lua`.
- En la configuración auditada del host no se encontró un overlay de highlights
  RefactorIA; no se confirmó su activación en runtime.
- Esta revisión no verificó diagnostics, floats, statusline ni todos los
  plugins o grupos de highlights. Una captura legible no prueba esos detalles.

### Muestra de paleta del default instalado

| Rol | Valor observado | Nota |
|-----|------------------|------|
| Fondo base | Transparente, dark | El fondo real depende del terminal y de la ventana; no se afirma un fondo opaco. |
| Texto principal | `#F3F6F9` | Foreground claro del default. |
| Texto muted | `#5C6170` | Texto secundario/apagado. |
| Surface 1 | `#191E28` | Superficie oscura. |
| Surface 2 | `#232A40` | Superficie elevada. |
| Surface 3 | `#313342` | Superficie de mayor contraste. |
| Surface 4 | `#27345C` | Superficie/acento profundo. |
| Acento gold | `#E0C15A` | Acento del theme, no token oficial de RefactorIA. |
| Acento green | `#B7CC85` | Acento semántico del theme. |
| Acento blue | `#7FB4CA` | Acento semántico del theme. |
| Acento magenta | `#FF8DD7` | Acento sintáctico del theme. |

Estos valores son una muestra del default instalado, no un inventario de cada
highlight. La transparencia puede cambiar la apariencia percibida sin que el
theme cambie.

## Origen y backups

- Origen histórico: `https://github.com/Gentleman-Programming/Gentleman.Dots`
- Subdirectorio usado en esa migración: `GentlemanNvim/nvim`
- Backup previo a la migración: `~/.config/nvim.backup-before-gentleman-20260619-183411`
- Backup LazyVim anterior: `~/.config/nvim.lazyvim-backup-20260619`

## Assets relacionados con la migración histórica

- Logo dashboard: `assets/refactoria-braille.txt`
- Fuente custom: `fonts/FiraCodeNerdFontMonoBeard-Reg.ttf`
- Script de regeneración: `fonts/patch_beard.py`

Estos assets pertenecen al trabajo de branding local. Su presencia no implica
que Neovim los use hoy ni que exista un overlay RefactorIA activo.

## Notas históricas no revalidadas

La siguiente información se conserva como contexto de una migración previa. No
debe leerse como estado actual del host ni como evidencia contra el theme
observado arriba:

- Mantener la configuración de Gentleman como base estable, evitando mezclar
  piezas sueltas.
- Mantener Oil como explorer principal en `-`.
- Mantener Neo-tree como explorer lateral en `<leader>e`.
- Mantener Oil flotante en `<leader>E`.
- Desactivar `mini.files` para evitar un tercer modelo de explorer.
- Hacer que `<leader>bq` cierre el buffer actual con `Snacks.bufdelete()`;
  evitar `edit #` porque puede saltar a buffers temporales en
  `/private/var/folders`.
- Pintar explícitamente `render-markdown.nvim` y desactivar `MD013`/`MD060`
  para documentación extensa.
- Habilitar ayudas de aprendizaje como `precognition.nvim`.
- Usar el logo RefactorIA y `FiraCode Nerd Font Mono Beard` en la GUI era una
  intención de esa migración; no se afirma como aplicada al estado actual.

## Archivos mencionados por la nota histórica

Los paths siguientes se conservan como referencias de trabajo anteriores; su
contenido actual no fue revalidado en esta corrección documental:

| Path | Nota histórica |
|------|----------------|
| `lua/plugins/ui.lua` | Header del dashboard con el Braille de RefactorIA. |
| `lua/plugins/markdown.lua` | Configuración de `render-markdown.nvim` y `markdownlint-cli2`. |
| `lua/plugins/precognition.lua` | Hints de movimientos Vim y sus keymaps. |
| `markdownlint-cli2.yaml` | Desactivación de `MD013` y `MD060`. |
| `lua/config/autocmds.lua` | Sin lógica custom de highlights. |
| `lua/config/options.lua` | Fuente GUI `FiraCode Nerd Font Mono Beard`. |
| `lua/config/lazy.lua` | Desactivación de `lazyvim.plugins.extras.editor.mini-files`. |
| `lua/config/keymaps.lua` | Alias `<leader>bq` para `Snacks.bufdelete()`. |

No se documenta ningún plugin local de theme no verificado: la referencia
anterior a un nombre-placeholder no correspondía a un archivo observado.

## Keymaps relevantes históricos (no revalidados)

| Keymap | Acción documentada históricamente |
|--------|-----------------------------------|
| `-` | Abrir Oil normal |
| `<leader>E` | Abrir Oil flotante |
| `<leader>e` | Abrir Neo-tree |
| `<leader>bq` | Cerrar buffer actual |
| `<leader>bd` | Cerrar buffer actual, default LazyVim/Snacks |
| `<leader>bo` | Cerrar otros buffers |
| `<leader>bD` | Cerrar buffer y ventana |
| `<leader>up` | Alternar Precognition hints |
| `<leader>uP` | Mostrar Precognition hints puntuales |

## Validación acotada y límites

Esta corrección es documental y no modificó el host. La evidencia disponible
incluye un arranque headless limpio, ejecutado por separado, y la apertura de un
buffer real por el usuario; esos checks sólo cubren carga y uso básico.

Para repetir el chequeo acotado de carga:

```bash
nvim --headless +'lua vim.defer_fn(function() print(vim.api.nvim_exec2("messages", { output = true }).output); vim.cmd("qa") end, 1500)'
```

No se hizo una auditoría completa de diagnostics, floats, statusline, plugins ni
todos los highlights. Esos estados siguen sin quedar afirmados por esta nota.

## Pendiente opcional

Versionar la configuración completa en `dotfiles/nvim/` y decidir si debe
crearse un symlink a `~/.config/nvim` sigue siendo un trabajo separado. Este
work unit no cambia el host ni `install.sh`.
