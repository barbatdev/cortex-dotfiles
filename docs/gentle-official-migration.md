# Migración a Gentle oficial: retiro del stack legacy

Runbook para retirar el stack Gentle legacy (launchers, wrappers, declaraciones de Pi, agentes y Orca) de un equipo **sin perder memoria, conversaciones ni credenciales**, y dejarlo listo para una instalación oficial posterior. Documenta lo que se hizo en `agent-dev`, el estado real y el plan para los demás equipos.

> **Estado honesto (2026-10-31):** el usuario confirmó que el instalador oficial terminó los 11 pasos en `agent-dev`: instaló Pi/Shell, verificó paquetes/comandos/Gentle AI, compiló Gentle AI desde `main`, instaló Shell desde `main`, guardó el canal y ejecutó setup. **El canal requerido es siempre `main`, no release.** El usuario mostró un arranque de Shell con extensiones cargadas y aviso de falta de modelos; decidió autenticarse otra vez. También confirmó setup de Claude Code completado (1 agente, 8 componentes), con aviso de integración Pi CodeGraph pendiente. Claude Code ya reportó instrucciones cargadas, detección de proyecto Engram y consulta real CodeGraph; la lectura de memorias anteriores y registro de sesión no se probaron. El usuario confirmó login y modelos disponibles en Shell. Los perfiles de macOS fueron restaurados y verificados por hash en el home aislado; el usuario confirmó que cargaron perfectamente en la interfaz. RefactorIA fue copiado al home aislado y verificado por hash; selección y comprobación visual pendientes. Quedan residuos preservados a propósito (ver [Residuos](#residuos-preservados)); no se afirma que el equipo esté "en cero".

## Resumen rápido

| Pregunta | Respuesta |
|----------|-----------|
| ¿Qué se preserva siempre? | Memoria (Engram), conversaciones, credenciales, `models.json`, `permission-mode.json`, Herdr/Moshi/status-bar, checkouts git. |
| ¿Qué se retira? | Launchers y wrappers legacy, declaraciones legacy en `settings.json`, Pi 0.85.1 global viejo, agentes Gentle legacy, Orca. |
| ¿Se borra algo? | Los scripts **mueven** a un backup privado; no borran. |
| ¿Cómo queda `gs`? | El arranque debe seguir siendo directo a `gentle-shell`, sin worktrees ni ruteo legacy. El usuario posteriormente pidió recuperar `gs sync` para actualizar siempre desde main; implementación pendiente. Un alias simple no puede interceptar `sync`: resolver ese despacho mínimo antes de implementarlo. |
| ¿Fuente de perfiles y tema? | La **Mac**. Respaldar desde ahí antes de tocarla. |

## Orden de equipos

| Orden planeado | Orden real |
|----------------|------------|
| 1. Mac → 2. `agent-dev` → 3. `agent-gentle` (dogfooding) | Se empezó por `agent-dev`. |

La desviación es explícita: empezar por `agent-dev` **no** implica aprobación para seguir con la Mac ni con `agent-gentle`. Cada equipo requiere su propia decisión.

---

## Runbook para un equipo nuevo

### 0. Antes de empezar (respaldos)

- [ ] En la **Mac**: respaldar los perfiles de ruteo de modelos (`profiles.json`) y el tema RefactorIA. La Mac es la fuente para recuperar otros equipos. Preservar además el agente propio `editor-refactoria` si existe; no es parte del theme.
- [ ] Confirmar que existe el backup validado **antes** de cualquier uninstall que pueda tocar recursos compartidos.
- [ ] No leer ni copiar credenciales, tokens ni drop-ins con secretos.

### 1. Uninstall oficial gestionado (`gentle-ai`)

Usar el menú oficial del instalador. Opciones relevantes:

| Opción del menú | Efecto |
|-----------------|--------|
| Full Uninstall | Remueve la config gestionada de **todos** los agentes. |
| Full Uninstall & Remove Binary | Lo anterior + remueve el binario `gentle-ai`. |
| Full Uninstall + Clean Install | Retira la configuración administrada y vuelve a sincronizar los assets; **no** equivale a desinstalar todos los binarios. |

En `agent-dev` se usó uninstall gestionado con scope *Global integration*; el backup quedó con id `20261031101655.564334205` y los recursos de Pi se retuvieron.

### 2. Self-uninstall (cuidado con lo compartido)

Desde una terminal fuera de la sesión de Gentle Shell, correr primero el modo dry-run y revisar su plan:

```sh
gentle-shell self-uninstall --dry-run
gentle-shell self-uninstall
```

Estos comandos se comprobaron en `agent-dev`. Si la versión instalada no los reconoce, consultar su ayuda y el procedimiento oficial para esa versión; no sustituirlos por otro comando ni desinstalar con un gestor sin identificar al propietario.

> ⚠️ **Cuando pregunte si remover recursos compartidos, responder NO** salvo que el backup de la Mac esté validado. En `agent-dev` se respondió *sí* y eso borró `profiles.json`; hay que recuperarlo desde la Mac.

> ⛔ **No usar `gentle-shell uninstall`** como alternativa: se reenvía a Pi como alias de su comando `remove` para paquetes; no desinstala Gentle Shell.

### 3. Retirar launchers y preferencias legacy

Script: [`scripts/retire-gentle-legacy.sh`](../scripts/retire-gentle-legacy.sh)

```bash
bash scripts/retire-gentle-legacy.sh            # dry-run (default)
bash scripts/retire-gentle-legacy.sh --apply    # mueve a ~/gentle-retirement.XXXXXX
```

Mueve solo esta lista fija (relativa a `$HOME`):

- `.local/bin/{gs,gentle-ai,gentle-shell,gentle-ai.pre-gw,gentle-shell.wrapper-backup}`
- `go/bin/gentle-ai`
- `.pi/agent/bin/pi`
- `.pi/gentle-ai/{notifications,history-capture,card-style}.json`

Salvaguardas: aborta si algún directorio padre es symlink o si el artefacto no es archivo/symlink; crea el backup con `mktemp` (nunca pisa uno existente); al aplicar verifica que no quede nada de la lista. No desinstala Pi ni paquetes, ni toca archivos de arranque del shell.

### 4. Limpiar declaraciones legacy en `settings.json` de Pi

Script: [`scripts/retire-gentle-pi-settings.py`](../scripts/retire-gentle-pi-settings.py)

```bash
python3 scripts/retire-gentle-pi-settings.py           # dry-run (default)
python3 scripts/retire-gentle-pi-settings.py --apply
```

Sobre `~/.pi/agent/settings.json` remueve únicamente:

- Paquetes: `git:github.com/Gentleman-Programming/engram@main`, `npm:pi-claude-bridge`, `npm:gentle-engram@0.4.0`, `npm:pi-web-access`, `npm:pi-btw`.
- `npmCommand: ["pnpm"]`.
- `-builtin:codemode` de `extensions` (vuelve a habilitar codemode builtin).

El backup (`~/gentle-settings-retirement.XXXX/removed-settings.json`) contiene **solo los campos removidos**, no el settings completo. Escribe de forma atómica y aborta si el archivo cambió durante la ejecución. No borra archivos de paquetes instalados.

> Los dos scripts son reutilizables **solo** si el equipo tiene el mismo layout legacy auditado. Siempre correr dry-run y leer la salida antes de `--apply`.

### 5. Pasos manuales (sin script)

Hacerlos solo después de verificar los paths en ese equipo; mover a un backup con `mktemp -d`, nunca borrar en bloque.

| Artefacto | Acción en `agent-dev` |
|-----------|------------------------|
| Pi 0.85.1 global viejo: `~/.npm-global/bin/pi` y `~/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent` | Movido a backup. |
| Agentes Gentle legacy en Pi: `gentle-ai-{explore,verify,worker}`, `jd-{fix-agent,judge-a,judge-b}`, `review-{readability,reliability,resilience,risk}` + `chains/4r-review.chain.md` | Movidos a backup. **Preservar `editor-refactoria`.** |
| Orca: tres extensiones de Pi | Movidas a backup. Herdr/Moshi se preservan. |
| Orca: drop-in `~/.config/systemd/user/orca-server.service.d` | Si existe, el operador conserva el directorio entero en un respaldo privado y luego ejecuta `systemctl --user daemon-reload`. No leer `gh.conf`: es privado y podría contener credenciales; su contenido no fue inspeccionado. |

Paquetes de Pi: revisar caso por caso con los comandos de Pi; no hay remoción en bloque. **No** borrar a mano directorios completos (`~/.pi`, `~/.gentle-ai`, cachés).

Configuración de permisos: es solo vía UI y la decide la persona; ningún script la borra ni la resetea.

### 6. Verificación

```zsh
whence -a gs gentle-ai gentle-shell pi   # ejecutar en una zsh NUEVA
```

Revisar cada ruta que aparezca; la ausencia de comandos no prueba por sí sola que no haya paquetes, servicios o procesos. Verificar también que ya no estén las declaraciones y recursos retirados, sin leer datos protegidos.

- Usar `--version`/`--help` solo de binarios que se sabe que están instalados.
- Una shell nueva no reemplaza procesos viejos: las sesiones de Node que ya corrían siguen con el código anterior hasta cerrarlas.
- No usar comandos de migración/recuperación de Engram como parte de esta verificación.

---

## Evidencia histórica: `agent-dev`

| Paso | Resultado observado | Backup |
|------|---------------------|--------|
| Uninstall gestionado (Global integration) | Hecho; recursos de Pi retenidos. | id `20261031101655.564334205` |
| Self-uninstall con shared = *sí* | Borró `profiles.json` (recuperar desde la Mac). | — |
| `retire-gentle-legacy.sh --apply` | 10 artefactos retirados y verificados. | `/home/jbarbat/gentle-retirement.bSFBGv` |
| `retire-gentle-pi-settings.py --apply` | 5 declaraciones + override pnpm + `-builtin:codemode` removidos y verificados. | `/home/jbarbat/gentle-settings-retirement.ealo82xr/removed-settings.json` |
| Pi 0.85.1 global | Launcher y paquete retirados. | `/home/jbarbat/gentle-pi-runtime-retirement.ajjdeg9h` |
| Agentes legacy | 10 agentes + `4r-review.chain.md` retirados. | `/home/jbarbat/gentle-agent-resources-retirement.vzef5ye9` |
| Orca | 3 extensiones retiradas y verificadas por el agente; el usuario confirmó mover el drop-in a `systemd-drop-in/` y ejecutar `daemon-reload`. | `/home/jbarbat/orca-retirement.90qcqnd4` |
| Unidades Orca | No se observaron unidades registradas. **Sin prueba completa** de que no queden procesos. | — |
| Instalador Linux nuevo | El usuario confirmó descarga/checksum y los 11 pasos completados en canal `main`, incluido setup. Arranque interactivo posterior pendiente. | — |

Los fallos de guardas que aparecieron en el camino quedan como historia, no como receta.

<a id="residuos-preservados"></a>

### Residuos preservados a propósito

- `~/.pi/agent/npm` (cachés y manifiesto de paquetes).
- Checkouts git.
- Extensiones propias: Herdr, Moshi, status-bar.
- Entrada de skills en settings, `models.json`, `permission-mode.json`.
- `~/.gentle-ai` (estado, cachés, backups).
- Servicio y procesos de Engram.
- Sesiones viejas de Node sin detener.

---

## Plan de migración futura

1. **Shell**: usar el instalador oficial con **Latest main**. El usuario requiere seguir siempre `main`. El plan observado instala globalmente con pnpm, compila Gentle AI desde `main`, reemplaza Shell por `main` y guarda el canal. La modalidad bundled release se propuso inicialmente, pero fue rechazada: no satisface el requisito de canal. Arrancar **sin `--link`** al principio y comprobar el home efectivo; no asumir las rutas/configuración de bundled.
2. **Claude Code**: el usuario usa únicamente **Gentle Shell y Claude Code**. El Gentle AI interno de Shell **no** configura Claude Code: completar el setup oficial de `gentle-ai` seleccionando solo Claude Code. No configurar Codex, OpenCode ni otros agentes.
3. **Canal y targets**: verificar contra el plan real que muestra el instalador. En una instalación compatible, `gentle-shell upgrade --channel main` es el mecanismo oficial de actualización de Shell y su Gentle AI desde `main`; guardar el canal no significa actualizar automáticamente en cada arranque. Comprobar por separado cómo se instala/actualiza el Gentle AI usado por Claude Code; no asumir que comparte el override interno de Shell.
4. **Arranque y sync**: inicialmente se pidió solo `alias gs='gentle-shell'`. Requisito posterior del usuario: conservar un futuro `gs sync` que traiga siempre Gentle AI desde main. El arranque sin subcomando debe seguir delegando directamente a Shell; el despacho mínimo de `sync` está pendiente de diseño/implementación, sin restaurar la orquestación legacy.
5. **Recuperar**: `profiles.json` y tema desde la Mac. En `agent-dev` se instaló `~/.gentle-shell/gentle-ai/profiles.json` (0600), verificado idéntico al de macOS por SHA-256 `d31b679fab6432426920756c6b1ca326e1c1451b69d88577f4633939cf018e73`. Ocho perfiles: current, openai, nan, openai-nan, claude, claude-nan, claude-openai y nan-qa-reliability-sol; activo `openai`. No se copiaron credenciales ni otros ajustes. La ruta se comprobó en el launcher instalado: el home aislado usa `GENTLE_SHELL_CONFIG_HOME`, diferente del estado global de canal/builds. Reiniciar Shell y verificar `/gentle:profiles`; no afirmar que ya cargó solo por copiar el archivo. El usuario confirmó la carga correcta de los perfiles en la interfaz. RefactorIA instalado en `~/.gentle-shell/agent/themes/refactoria.json`, idéntico al archivo `pi/themes/refactoria.json` del repo (SHA-256 `1f4b0788bb5141b1dbc9d58c786f8556a14a0e768db923dbc6dc2a77f726a8f2`, modo 0644). No se modificó el theme seleccionado; elegir `refactoria` desde `/gentle:customize` y comprobar visualmente.
6. **Wizard headless**: si el wizard abre en `localhost`, usar port forwarding (por ejemplo SSH). **No** publicar la URL de un solo uso (contiene un secreto) ni bindear a `0.0.0.0`.

### Criterios para cerrar cada equipo

- [ ] Instalador oficial: origen y checksum verificados, plan **Latest main** revisado, canal y versiones/commits instalados registrados.
- [ ] Arranque nuevo de Shell en su entorno aislado; sin cargar el home legacy mediante `--link`.
- [ ] Perfiles restaurados: comprobar modelos, razonamiento y asignaciones por rol en la interfaz, no solo la existencia del archivo.
- [ ] RefactorIA restaurado y seleccionado; comprobación visual por el usuario.
- [ ] Gentle AI configurado en los agentes elegidos y comprobado por separado de Shell.
- [ ] Memorias, conversaciones y credenciales anteriores conservadas; no afirmar que el entorno aislado las importó automáticamente.
- [ ] Compatibilidad del servidor Engram comprobada por el flujo oficial; si no puede verificarse, detener la parte de memoria sin borrar datos ni forzar migraciones.
- [ ] Arranque de `gs` delegado directamente a Shell, sin el script legacy. Futuro `gs sync` actualiza Shell y Gentle AI externo desde main y no vuelve silenciosamente a release; pendiente implementar y verificar.
- [ ] Orca sin integraciones activas; Herdr/Moshi conservados.
- [ ] Registrar pruebas pendientes y respaldos antes de pasar al siguiente equipo. `agent-gentle` requiere un plan separado para su dogfooding; no convertir sus clones en una instalación consumer por defecto.

## Setup de Claude Code: incidencia de CodeGraph

El primer intento falló en `community-tool:codegraph` con rollback reportado. La auditoría remota comprobó que `~/npm-global/bin/codegraph --version` funcionaba (1.6.2, exit 0), pero zsh no encontraba ese comando. `npm prefix -g` devolvió `/home/jbarbat/npm-global`.

Para repetir en un equipo con **ese prefijo comprobado**, el operador puede ajustar solo la terminal actual:

```zsh
export PATH="$HOME/npm-global/bin:$PATH"
rehash
codegraph --version
gentle-ai
```

No reinstalar CodeGraph si el problema es únicamente PATH. No copiar esta ruta a otro equipo sin comprobar su prefijo. La persistencia en dotfiles sigue pendiente.

El usuario luego informó `Done! Your AI agents are ready`, 1 agente configurado y 8 componentes instalados. Esto confirma que el setup terminó, no que Claude Code ya haya sido probado en una sesión real.

El resumen también informó `Pi CodeGraph integration remains pending` (mensaje mostrado truncado). Como el setup elegido es solo Claude Code, no activar ni reparar la integración Pi por defecto: revisar el detalle completo si se necesita. La capacidad MCP directa se reportó verificada por el instalador; no equivale a una prueba de todas las herramientas de Claude Code.

GGA se reportó instalado globalmente. `gga init` y `gga install` son acciones por repositorio: no ejecutarlas en todos los proyectos ni modificar hooks sin decidirlo para cada uno.

## Requisito pendiente: `gs sync` y Gentle AI externo desde main

Corrección del usuario, textual:

> esto tenes que documentarlo para después en el gs sync traerlo siempre de main eh ... no te olvides

- `go install github.com/gentleman-programming/gentle-ai/v4/cmd/gentle-ai@main` instala una **foto de main**; no deja un canal persistente ni se actualiza solo.
- El futuro `gs sync` debe volver a traer Gentle AI externo desde **main** mediante ese comando, o mediante un mecanismo oficial que se verifique equivalente. No usar `@latest`, un tag estable ni asumir que `gentle-ai update` conserva main sin comprobarlo.
- Shell mantiene su mecanismo oficial `gentle-shell upgrade --channel main`. No asumir que ese comando actualiza el Gentle AI externo que usa Claude Code.
- Después de actualizar, comprobar qué binario externo resuelve el PATH y qué versión/commit quedó instalado; evitar actualizar una copia y ejecutar otra. Definir y verificar el mecanismo oficial de sincronización de assets de Claude Code cuando se implemente.
- Implementado en [`bin/gs-official`](../bin/gs-official) ([doc](gs-official.md)), desplegado solo en hosts migrados como `~/.local/bin/gs`. El `bin/gs` legacy de Mac y workshop no cambia. El PATH permanente se activa con el fragmento opt-in [`zsh/scripts/official-gentle-path.zsh`](../zsh/scripts/official-gentle-path.zsh), enlazado en `~/.config/cortex-dotfiles/shell/official-gentle-path.zsh`.
- El instalador oficial `install.sh --channel beta` falló en esta sesión: `get_main_commit_sha` emite un mensaje informativo en stdout y su captura mezcla ese mensaje con el SHA, causando una URL inválida al buscar `go.mod`. Se comprobó en el script remoto. No parchear el instalador ni desactivar verificaciones como workaround.
- También hubo un error de pegado independiente (`\\ |` en una misma línea). Corregir el pegado no arregla el bug del instalador.

## Rollback

Parcial y por archivo de backup: restaurar **solo** el artefacto puntual que se necesite, sin pisar lo que dejó la instalación nueva. **Nunca** restaurar el `settings.json` viejo completo; el backup de settings solo tiene los campos removidos, para reinsertarlos uno a uno si hace falta.

## Decisiones pendientes

- [x] Agentes definidos por el usuario: **Gentle Shell y Claude Code solamente**. Setup externo de Gentle AI limitado a Claude Code.
- [ ] Aprobación para avanzar con la Mac y con `agent-gentle`.
- [ ] Recuperación de `profiles.json` en `agent-dev` desde la Mac.
- [x] Instalador Linux completado en `agent-dev`, confirmado por la salida del usuario (11 pasos, canal main).
- [ ] Confirmar arranque interactivo posterior de Gentle Shell y home/canal efectivos.

## Fuentes

Fuentes consultadas durante la sesión; revisar nuevamente la versión vigente antes de repetir en otro equipo:

- Gentle Shell, instalación y actualización: <https://github.com/Gentleman-Programming/gentle-shell#-get-started>
- Asistente oficial: <https://github.com/Gentleman-Programming/gentle-shell/blob/main/docs/install-wizard.md>
- Instalación autocontenida y migración: <https://github.com/Gentleman-Programming/gentle-shell/blob/main/docs/bundled-install.md>
- Desinstalación de Shell: <https://github.com/Gentleman-Programming/gentle-shell/blob/main/docs/gentle-shell-uninstall.md>
- Releases oficiales: <https://github.com/Gentleman-Programming/gentle-shell/releases/latest>
- Gentle AI: <https://github.com/Gentleman-Programming/gentle-ai>
- Opciones de uninstall de Gentle AI: <https://github.com/Gentleman-Programming/gentle-ai/blob/main/internal/tui/screens/uninstall.go>
- Engram: <https://github.com/Gentleman-Programming/engram>

## macOS

Script: [`scripts/migrate-mac-official.sh`](../scripts/migrate-mac-official.sh). Replica en la Mac lo hecho en `agent-dev` en una sola corrida.

- **Correr fuera de Gentle Shell**, desde una terminal común con todas las sesiones cerradas: el script desinstala el Shell legacy (npm global en `~/.local`) y una sesión abierta seguiría usando ese código. El preflight lo bloquea si detecta procesos de `gentle-shell`.
- Usa el camino oficial **npm + `gentle-shell upgrade --channel main`** (el método de instalación que ya tenía la Mac), no el wizard del navegador. Luego `gentle-shell setup`, restaura perfiles y RefactorIA en el home aislado, compila Gentle AI desde `main` en `~/.local/bin` para Claude Code y enlaza `gs-official`.
- No usa `--include-shared`, no toca Engram ni LaunchAgents, y **mueve** los launchers legacy y las extensiones Orca a `~/gentle-mac-retirement.XXXXXX`.

```bash
bash scripts/migrate-mac-official.sh --backup ~/gentle-migration-backup.GhUgKM          # dry-run
bash scripts/migrate-mac-official.sh --backup ~/gentle-migration-backup.GhUgKM --apply
```

`~/.pi/agent` (conversaciones, auth, settings) se preserva, pero el home aislado (`~/.gentle-shell/agent`) no lo usa: después de migrar hay que abrir una terminal nueva, correr `gs`, hacer `/login` y revisar `/gentle:profiles`.
