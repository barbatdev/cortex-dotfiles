# Migración yabai → AeroSpace (macOS 27)

macOS 27 rompió yabai (scripting addition roto, sin release con fix). El usuario usaba principalmente el tiling. AeroSpace cubre tiling + focus + workspaces sin SIP y sin inyección.

## Specs

- S1 (user): "que tanta integración? si no hacemos mucho tampoco" — integración mínima; SketchyBar sigue igual.
- S2 (user): "Lo que mas usaba era el tiling" — prioridad tiling automático.
- S3 (user): "si metelo en un loop y no pares hasta que quede hecho" — migración completa sin pausas.
- S4: mismo leader `alt+cmd`, mismos atajos 1..9 y hjkl que skhd.

## Tasks

- [x] T1 (S4): `aerospace/aerospace.toml` — config porteada 1:1 (commit e6156ac).
- [x] T2: install.sh symlink + cask nikitabobko/tap.
- [x] T3: baja yabai/skhd (configs archivados en `archive/yabai-migration/`, brew uninstall + untap).
- [x] T4: fix `split` → `layout tiles accordion` (incompatible con normalización).
- [ ] T5: borrado con sudo de `/Library/ScriptingAdditions/yabai.osax` y regla NOPASSWD de yabai en sudoers — requiere password del usuario.

## Log

- L1 (user): "ayer te pedí sacar yabai... no era eso lo que me estaba jodiendo. Desde que entro macos 27 empezó a joder mal yabai y capaz ya sacaron alguna actualización?"
- L2: verificado — yabai 7.1.25 no soporta macOS 27; fixes en master sin release; mantenedor poco activo (#2684). Decisión: migrar a AeroSpace 0.21.3-Beta.
- L3: AeroSpace requiere Accesibilidad (gate del usuario); otorgado. Server arriba, 3 ventanas gestionadas, workspaces 1..9.
## Log

- L5 (cierre revert): AeroSpace era inestable en el combo real (macOS 27 + 4 monitores: crashes + desync workspace↔space). Revert a yabai 7.1.25 parcheado (#2800, alias 27→26, binario compilado y reemplazado en Cellar) + skhd como LaunchAgents de usuario. Tiling y atajos verificados. Sin SA: space ops no-op — el usuario confirmó que no usa espacios de yabai. osax /Library/ScriptingAdditions/yabai.osax borrado con sudo (confirmado ausente). Pendiente menor: ninguno bloqueante.

## Notas

- Rotate/mirror/balance de yabai no existen en i3-tree: mapeados a join-with/resize.
- Mouse move/resize con modificador (alt+drag) no existe en AeroSpace.
- Config-version 1 con warning de migración a 2 — funciona, migración diferida.
