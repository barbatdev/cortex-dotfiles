# Neovim

Estado documentado el 2026-06-19. La configuración activa vive por ahora en
`~/.config/nvim` y parte de una copia directa de `Gentleman.Dots`.

## Base

- Repo upstream: `https://github.com/Gentleman-Programming/Gentleman.Dots`
- Subdirectorio usado: `GentlemanNvim/nvim`
- Config local activa: `~/.config/nvim`
- Backup previo a la migración: `~/.config/nvim.backup-before-gentleman-20260619-183411`
- Backup LazyVim anterior: `~/.config/nvim.lazyvim-backup-20260619`

## Decisiones

- Mantener la config de Gentleman como base estable, evitando mezclar piezas sueltas.
- Mantener Oil como explorer principal en `-`.
- Mantener Neo-tree como explorer lateral en `<leader>e`.
- Mantener Oil flotante en `<leader>E`.
- Desactivar `mini.files` para evitar un tercer modelo de explorer.
- Usar el logo RefactorIA real del repo, no el mostacho upstream.
- Aplicar un overlay visual InnIT/RefactorIA sobre el theme upstream, en vez de reemplazar todo el colorscheme.
- Usar como fuente cromática canónica los tokens de un proyecto web local configurado por el usuario.
- Usar `FiraCode Nerd Font Mono Beard` como fuente GUI.
- Hacer que `<leader>bq` cierre el buffer actual con `Snacks.bufdelete()`; no usar `edit #` porque puede saltar a buffers temporales en `/private/var/folders`.
- Pintar explícitamente `render-markdown.nvim` con la paleta InnIT; los grupos base no alcanzan porque Markdown usa highlights propios.
- Desactivar reglas ruidosas de markdownlint (`MD013`, `MD060`) para docs/runbooks largos.
- Habilitar ayudas de aprendizaje como `precognition.nvim`; todo lo que muestre movimientos/contexto útil es deseable en esta etapa.

## Assets

- Logo dashboard: `dotfiles/assets/refactoria-braille.txt`
- Fuente custom: `dotfiles/fonts/FiraCodeNerdFontMonoBeard-Reg.ttf`
- Script de regeneración: `dotfiles/fonts/patch_beard.py`

## Paleta usada para el overlay

Derivada de los tokens CSS del proyecto web local configurado por el usuario.

| Uso | Color |
|-----|-------|
| Fondo base | `#0F1419` |
| Surface | `#1C2128` |
| Surface elevada / cursor line | `#2D333B` |
| Texto principal | `#F6F8FA` |
| Texto secundario | `#8B949E` |
| Texto muted/comment | `#57606A` |
| CTA azul InnIT | `#0054ff` |
| Azul hover | `#1a68ff` |
| Azul informativo | `#58A6FF` |
| Verde engineering | `#3FB950` |
| Verde hover | `#4CC55E` |
| Warning | `#D29922` |
| Error | `#F85149` |
| Purple sintaxis | `#A371F7` |

## Archivos modificados en `~/.config/nvim`

- `lua/plugins/ui.lua`
  - Header del dashboard reemplazado por `assets/refactoria-braille.txt`.
- `lua/plugins/<local-theme>.lua`
  - Overlay de highlights InnIT/RefactorIA cargado como plugin spec de Lazy.
  - Incluye grupos base, diagnostics y grupos `RenderMarkdown*`.
- `lua/plugins/markdown.lua`
  - Config de `render-markdown.nvim` y override de `markdownlint-cli2`.
- `lua/plugins/precognition.lua`
  - Hints de movimientos Vim activos por defecto.
  - `<leader>up` alterna hints automáticos.
  - `<leader>uP` muestra hints puntuales con `peek`.
- `markdownlint-cli2.yaml`
  - Desactiva `MD013` y `MD060`.
- `lua/config/autocmds.lua`
  - Queda sin lógica custom; el overlay vive en un plugin local para asegurar orden de carga.
- `lua/config/options.lua`
  - `vim.opt.guifont = "FiraCode Nerd Font Mono Beard:h14"`.
- `lua/config/lazy.lua`
  - `lazyvim.plugins.extras.editor.mini-files` comentado/desactivado.
- `lua/config/keymaps.lua`
  - `<leader>bq` como alias seguro de `Snacks.bufdelete()`.

## Estado de keymaps relevantes

| Keymap | Acción |
|--------|--------|
| `-` | Abrir Oil normal |
| `<leader>E` | Abrir Oil flotante |
| `<leader>e` | Abrir Neo-tree |
| `<leader>bq` | Cerrar buffer actual |
| `<leader>bd` | Cerrar buffer actual, default LazyVim/Snacks |
| `<leader>bo` | Cerrar otros buffers |
| `<leader>bD` | Cerrar buffer y ventana |
| `<leader>up` | Alternar Precognition hints |
| `<leader>uP` | Mostrar Precognition hints puntuales |

## Validación manual

```bash
nvim --headless +'lua vim.defer_fn(function() print(vim.api.nvim_exec2("messages", { output = true }).output); vim.cmd("qa") end, 1500)'
```

Resultado esperado: sin errores en `:messages`.

## Pendiente opcional

Versionar la config completa en `dotfiles/nvim/` y hacer que `install.sh` cree el symlink a
`~/.config/nvim`, siguiendo el patrón del resto de herramientas.
