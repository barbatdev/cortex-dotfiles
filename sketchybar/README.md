# Workspaces de OmniWM en SketchyBar

La barra muestra los workspaces de OmniWM en cada monitor (en lugar de los Spaces nativos de macOS): el activo resaltado, click para cambiar y actualización por eventos, sin polling. El resto de los items de la barra no cambia.

## Activación (una sola vez)

1. Habilitar el IPC local en OmniWM (lo decide el usuario; el listener no lo activa).
2. Instalar el agente launchd reemplazando las rutas del template:

   ```bash
   sed -e "s#__PYTHON__#/opt/homebrew/bin/python3#" \
       -e "s#__CONFIG_DIR__#$HOME/.config/sketchybar#" \
       sketchybar/omniwm-workspaces.plist \
       > ~/Library/LaunchAgents/com.cortex.omniwm-workspaces.plist
   ```

3. Recargar la barra: `sketchybar --reload`. El `sketchybarrc` llama a `plugins/omni_workspaces.sh`, que arranca el agente o lo reinicia (`kickstart -k`) para tomar un snapshot fresco.
4. Verificar: aparecen items `omni.ws.<uuid>` → `sketchybar --query bar | jq '.items'`.

## Cómo funciona

| Pieza | Rol |
|-------|-----|
| `plugins/omni_workspaces.py` | Listener único (lock `fcntl` en `~/.cache/cortex/omni-workspaces.lock`). Corre `omniwmctl subscribe workspace-bar,display-changed --reconnect --format ndjson` y aplica cambios con una sola llamada `sketchybar` por evento. |
| `plugins/omni_workspaces.sh` | Lifecycle desde `sketchybarrc`: solo toca el label `com.cortex.omniwm-workspaces` (`bootstrap` o `kickstart -k`). Nunca usa `kill`/`pkill`. |
| `omniwm-workspaces.plist` | Template del agente launchd con Python explícito (no depende del `PATH`). |

- **Monitores**: el `id` de Omni (`display:<CGDirectDisplayID>`) se mapea al `arrangement-id` de `sketchybar --query displays` en cada actualización; el mapeo no se guarda entre reconexiones.
- **Click**: ejecuta `omniwmctl workspace focus-name <rawName>` con el nombre escapado (`shlex.quote`).
- **Labels**: se cortan a 10 caracteres (`…`) para que entren en monitores angostos.
- **Desconexión**: se eliminan todos los items `omni.ws.*`, así nada queda falsamente activo.
- **Reintentos**: si OmniWM no está corriendo (exit 2), reintenta con backoff hasta 30 s. Si el IPC está denegado (exit 1), termina sin reintentar.
- **Dependencias**: `/opt/homebrew/bin/omniwmctl` (OmniWM 0.8.0), `/opt/homebrew/bin/sketchybar`, `python3` (solo stdlib). Rutas sobrescribibles con `OMNIWMCTL` y `SKETCHYBAR`.

## Gestores retirados

Yabai y skhd no son dependencias del stack actual. Sus fórmulas, servicios de usuario y enlaces `~/.yabairc` / `~/.skhdrc` fueron retirados del host durante la migración; el instalador ya no enlaza yabai. Las configuraciones efectivas previas se conservan en `archive/omniwm-migration/` solo como referencia. Restaurar archivos no reinstala los binarios ni los servicios. OmniWM, SketchyBar y Karabiner permanecen activos.

## Recuperación manual

| Síntoma | Acción |
|---------|--------|
| No aparecen workspaces | `launchctl print gui/$(id -u)/com.cortex.omniwm-workspaces` y revisar `last exit code`. Exit 1 = IPC denegado: habilitarlo y recargar la barra. |
| Workspaces desactualizados | `launchctl kickstart -k gui/$(id -u)/com.cortex.omniwm-workspaces` |
| Quitar la integración | `launchctl bootout gui/$(id -u)/com.cortex.omniwm-workspaces` y borrar el plist de `~/Library/LaunchAgents`. |
