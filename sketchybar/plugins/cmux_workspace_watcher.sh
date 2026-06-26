#!/bin/bash

# Watcher de workspace cmux para SketchyBar.
#
# Este script se invoca desde SketchyBar y mantiene una suscripción a eventos cmux
# para mantener sincronizados los widgets izquierdos con el workspace visible/enfocado.
#
# Modelo canónico (cmux v0.64.13):
#   - Invocar cmux SIEMPRE con `env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux ...`
#     para que auto-descubra el socket vivo en lugar de usar el socket muerto heredado
#     del entorno (inyectado por cmux upstream opcode-plugin.js en settings.json).
#   - Los eventos window.keyed / workspace.selected / workspace.renamed son SEÑAL,
#     no verdad. La VERDAD se re-deriva invocando cmux-focused-workspace.sh
#     (T1, productor único).
#   - NO parsear event.payload.cwd — es caller-biased y puede diferir del .focused.
#   - Ante resume.gap (boot_id cambia al reiniciar cmux), re-bootstrapear con snapshot.
#   - `--reconnect` de cmux NO re-resuelve el socket path; si el stream muere de forma
#     irrecuperable, el watcher mata el proceso hijo y reintenta con backoff;
#     gracias al env -u, el nuevo intento auto-descubre el socket nuevo.
#   - Un solo watcher garantizado por lock con PID; proceso cmux events hijo muerto
#     limpiamente al salir o reiniciar (trap + kill del PID hijo).
#
# DISEÑO DEL LOOP DE CONSUMO:
#   - PIPE DIRECTO via process substitution (< <(...)): el while corre en el shell
#     padre, por lo que las variables de estado (last_boot_id, last_refresh) persisten
#     entre iteraciones. Al EOF del pipe (cmux termina o socket muere), el while sale
#     y el loop externo reconecta con backoff.
#   - DEBOUNCE con $SECONDS: variable built-in de bash, entera y monotónica. El refresh
#     se dispara en cuanto llega el primer evento relevante de una ráfaga y los eventos
#     siguientes dentro del mismo segundo quedan absorbidos sin re-derivar. Evita el
#     atragantamiento ante ráfagas densas (p. ej. eventos en cascada).
#   - SIN REPLAY: NO se usa --cursor-file. El bootstrap toma un snapshot fresco antes
#     de arrancar el stream; se descubre el latest_seq del ack inicial y se arranca
#     con --after <latest_seq> para recibir SOLO eventos nuevos.
#   - LOGGING: el stderr de `cmux events` y los diagnósticos del watcher se anexan a
#     un log rotado por tamaño para poder diagnosticar en vivo.

# ── Variables de entorno y paths ────────────────────────────────────────────
plugin_dir="$(cd "$(dirname "$0")" && pwd)"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/cortex"
lock_file="$cache_dir/sketchybar-cmux-workspace-watcher.lock"
log_file="$cache_dir/cmux-sketchybar-watcher.err.log"
log_max_bytes=1048576   # 1 MiB: rotado simple por truncado al cruzar este tamaño.

# Ruta del helper T1 — productor único de verdad y del cache.
helper="$plugin_dir/../../zsh/scripts/cmux-focused-workspace.sh"

# PID del proceso `cmux events` hijo (para reaping al salir o reiniciar).
CMUX_EVENTS_PID=""

mkdir -p "$cache_dir"

# ── Logging ──────────────────────────────────────────────────────────────────
# Rotado simple: si el log cruza el límite, truncarlo antes de seguir anexando.
log() {
    local size=0
    if [[ -f "$log_file" ]]; then
        size=$(wc -c <"$log_file" 2>/dev/null | tr -d '[:space:]')
        size=${size:-0}
    fi
    if (( size > log_max_bytes )); then
        : >"$log_file"
    fi
    printf '%s [watcher %d] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$$" "$*" >>"$log_file" 2>/dev/null || true
}

# ── Lock anti-huérfanos: un solo watcher a la vez (robusto, con PID) ─────────
# Lock basado en archivo con el PID adentro. Si el lock existe pero su PID ya no
# vive (instancia muerta sin limpiar), se considera stale y se reclama. Si el PID
# vive, hay otro watcher legítimo y salimos. Se usa noclobber para evitar la
# carrera entre el test de stale y la toma del lock.
acquire_lock() {
    # Intento atómico de creación.
    if ( set -o noclobber; printf '%s\n' "$$" >"$lock_file" ) 2>/dev/null; then
        return 0
    fi
    # El lock ya existe: chequear si su dueño sigue vivo.
    local owner
    owner=$(cat "$lock_file" 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$owner" ]] && kill -0 "$owner" 2>/dev/null; then
        # Dueño vivo → ya hay un watcher corriendo; esta instancia aborta.
        log "lock ocupado por PID ${owner} (vivo); esta instancia ($$) sale sin hacer nada"
        return 1
    fi
    # Lock stale (dueño muerto o PID ilegible): reclamarlo.
    log "lock stale (owner='${owner}' inactivo o ilegible); reclamando para PID $$"
    if ( set -o noclobber; printf '%s\n' "$$" >"${lock_file}.tmp.$$" ) 2>/dev/null; then
        mv -f "${lock_file}.tmp.$$" "$lock_file" 2>/dev/null || { rm -f "${lock_file}.tmp.$$" 2>/dev/null; return 1; }
        # Confirmar que somos los dueños tras la reclamación.
        owner=$(cat "$lock_file" 2>/dev/null | tr -d '[:space:]')
        [[ "$owner" == "$$" ]] && return 0
    fi
    return 1
}

if ! acquire_lock; then
    log "salida temprana: otro watcher ya está activo o lock no adquirido"
    exit 0
fi

# Trap: matar el proceso hijo `cmux events` y soltar el lock SIEMPRE al salir.
# Solo borramos el lock si seguimos siendo los dueños (evita pisar a un sucesor).
cleanup() {
    if [[ -n "$CMUX_EVENTS_PID" ]] && kill -0 "$CMUX_EVENTS_PID" 2>/dev/null; then
        kill "$CMUX_EVENTS_PID" 2>/dev/null || true
        wait "$CMUX_EVENTS_PID" 2>/dev/null || true
    fi
    local owner
    owner=$(cat "$lock_file" 2>/dev/null | tr -d '[:space:]')
    [[ "$owner" == "$$" ]] && rm -f "$lock_file" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ── Detección del binario cmux ───────────────────────────────────────────────
# Orden de resolución (de más a menos confiable):
#   1. cmux en PATH (entorno rico: zsh interactivo, iTerm, etc.)
#   2. Ruta absoluta canónica del bundle de macOS (presente bajo SketchyBar con PATH mínimo)
#   3. Variables de entorno de fallback inyectadas externamente (CMUX_BUNDLED_CLI_PATH,
#      CMUX_CLAUDE_HOOK_CMUX_BIN) — permiten override sin tocar este script.
# Mismo patrón que dotfiles/zsh/scripts/cmux-focused-workspace.sh (T1, productor único).
CMUX_BIN=""
if command -v cmux >/dev/null 2>&1; then
    CMUX_BIN="cmux"
elif [[ -x "/Applications/cmux.app/Contents/Resources/bin/cmux" ]]; then
    CMUX_BIN="/Applications/cmux.app/Contents/Resources/bin/cmux"
elif [[ -n "${CMUX_BUNDLED_CLI_PATH:-}" && -x "${CMUX_BUNDLED_CLI_PATH}" ]]; then
    CMUX_BIN="$CMUX_BUNDLED_CLI_PATH"
elif [[ -n "${CMUX_CLAUDE_HOOK_CMUX_BIN:-}" && -x "${CMUX_CLAUDE_HOOK_CMUX_BIN}" ]]; then
    CMUX_BIN="$CMUX_CLAUDE_HOOK_CMUX_BIN"
else
    log "ERROR: binario cmux no encontrado (PATH mínimo de SketchyBar). Revisar instalación."
    printf '%s [watcher %d] cmux no encontrado; watcher no puede arrancar.\n' \
        "$(date '+%Y-%m-%dT%H:%M:%S')" "$$" >>"$log_file" 2>/dev/null || true
    exit 0
fi

# Wrapper con env limpio: neutraliza CMUX_SOCKET_PATH y CMUX_SOCKET heredados del entorno.
# cmux auto-descubre el socket vivo en ~/.local/state/cmux/cmux.sock (socketControlMode=allowAll).
CMUX="env -u CMUX_SOCKET_PATH -u CMUX_SOCKET $CMUX_BIN"

command -v jq >/dev/null 2>&1 || exit 0

# ── Función: re-derivar la verdad e invocar los widgets ─────────────────────
# Ante cualquier evento relevante (window.keyed, workspace.selected,
# workspace.renamed) o gap, este helper es la ÚNICA fuente de verdad; no se parsea
# el payload del evento. El debounce con $SECONDS la invoca UNA vez por segundo
# de ráfaga (ver loop principal).
refresh_workspace() {
    local cwd
    if [[ -x "$helper" ]]; then
        # T1 escribe el cache y emite el cwd por stdout.
        cwd=$("$helper" 2>/dev/null) || return 0
    else
        # Fallback: leer el cache si el helper no está disponible.
        local wf="${CORTEX_ACTIVE_WORKSPACE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/cortex/active-workspace}"
        [[ -f "$wf" ]] && cwd=$(sed -n '1p' "$wf") || return 0
    fi
    [[ -n "$cwd" ]] || return 0
    sketchybar --trigger workspace_change SKETCHYBAR_WORKSPACE="$cwd" >/dev/null 2>&1 || true
    SKETCHYBAR_WORKSPACE="$cwd" NAME=workspace_context "$plugin_dir/workspace_context.sh" >/dev/null 2>&1 || true
}

# ── Descubrir el latest_seq del ack ─────────────────────────────────────────
# Se abre una suscripción efímera solo para leer el ack frame, del que extraemos
# resume.latest_seq. Arrancar el stream real con --after <latest_seq> garantiza
# que NO se arrastre el replay histórico (causa del atragantamiento en vivo).
# Devuelve el seq por stdout, o vacío si no se pudo obtener.
discover_latest_seq() {
    # Suscripción efímera: leer SOLO el ack frame y matar el proceso enseguida.
    # NO usamos `| head -1`: ese pipeline cuelga porque `cmux events` no recibe
    # SIGPIPE de forma confiable (buffering) y el `$()` espera a todo el pipeline.
    # En su lugar lanzamos cmux events a un FIFO propio, leemos una línea con
    # timeout y matamos el proceso por PID. Robusto y acotado en el tiempo.
    local probe_fifo="$cache_dir/cmux-ack.$$.fifo"
    rm -f "$probe_fifo" 2>/dev/null || true
    mkfifo "$probe_fifo" 2>>"$log_file" || return 0

    $CMUX events --category window --category workspace --no-heartbeat \
        2>>"$log_file" >"$probe_fifo" &
    local probe_pid=$!

    local ack=""
    # FD 4 (numérico fijo: bash 3.2 de macOS no soporta {var}<> named FDs).
    # Modo <> evita bloqueo en el open si el productor tarda en abrir su extremo.
    exec 4<>"$probe_fifo"
    rm -f "$probe_fifo" 2>/dev/null || true
    IFS= read -r -t 2 ack <&4 || true
    exec 4<&- 2>/dev/null || true

    kill "$probe_pid" 2>/dev/null || true
    wait "$probe_pid" 2>/dev/null || true

    [[ -z "$ack" ]] && return 0
    printf '%s' "$ack" | jq -r '.resume.latest_seq // empty' 2>/dev/null
}

# ── Bootstrap inicial: snapshot de la verdad actual ─────────────────────────
# Antes de arrancar el stream, tomar el estado real del workspace visible.
log "bootstrap: snapshot inicial de la verdad"
refresh_workspace

# ── Bucle principal: backoff + descubrimiento de seq + consumo directo del pipe ─
backoff=2
max_backoff=30

while true; do
    # Verificar que seguimos siendo dueños del lock. Si otra instancia lo reclamó
    # (p.ej. tras un reload de SketchyBar que no mató esta instancia limpiamente),
    # salir en vez de competir con el nuevo watcher legítimo.
    _lock_owner=$(cat "$lock_file" 2>/dev/null | tr -d '[:space:]')
    if [[ "$_lock_owner" != "$$" ]]; then
        log "lock perdido (owner actual: '${_lock_owner}', yo: $$); saliendo"
        exit 0
    fi

    # Verificar que cmux responde antes de abrir el stream.
    if ! $CMUX ping >/dev/null 2>&1; then
        log "cmux ping falló; backoff ${backoff}s"
        sleep "$backoff"
        backoff=$(( backoff < max_backoff ? backoff * 2 : max_backoff ))
        continue
    fi

    # Descubrir el seq actual para arrancar SOLO desde eventos nuevos (sin replay).
    latest_seq=$(discover_latest_seq)
    if [[ -z "$latest_seq" ]]; then
        log "no se pudo descubrir latest_seq; backoff ${backoff}s"
        sleep "$backoff"
        backoff=$(( backoff < max_backoff ? backoff * 2 : max_backoff ))
        continue
    fi
    log "stream desde --after ${latest_seq} (solo eventos nuevos, sin replay)"
    backoff=2

    # Consumo directo via process substitution (< <(...)): el while corre en el
    # shell PADRE, no en subshell como haría `cmd | while`. Las variables de estado
    # (last_boot_id, last_refresh) persisten entre iteraciones del loop interno.
    # Al EOF del pipe, el while sale y el loop externo reconecta con backoff.
    # $! después del `done` es el PID del proceso dentro del <(...); suficiente
    # para reaping al cierre (el proceso hijo recibe SIGTERM al exit del padre).
    last_boot_id=""
    last_refresh=0
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue

        event_name=$(printf '%s' "$event" | jq -r '.name // empty' 2>/dev/null)

        case "$event_name" in
            # Señal: cambió el workspace o la ventana activa.
            # NO parsear .payload.cwd — es caller-biased. Solo re-derivar la verdad.
            # Debounce con $SECONDS: disparar refresh solo si pasó al menos 1s
            # desde el último refresh (agrupa ráfagas de eventos consecutivos).
            "window.keyed"|"workspace.selected"|"workspace.renamed")
                if [[ "$last_refresh" -ne "$SECONDS" ]]; then
                    last_refresh=$SECONDS
                    refresh_workspace
                fi
                ;;

            # Gap de cursor: cmux fue reiniciado (boot_id nuevo).
            # El estado pudo desincronizarse → forzar refresh inmediato sin
            # esperar al debounce, y actualizar el boot_id de referencia.
            "resume.gap")
                new_boot_id=$(printf '%s' "$event" | jq -r '.boot_id // empty' 2>/dev/null)
                if [[ -n "$new_boot_id" && "$new_boot_id" != "$last_boot_id" ]]; then
                    last_boot_id="$new_boot_id"
                    log "resume.gap boot_id=${new_boot_id}; re-bootstrap inmediato"
                    last_refresh=$SECONDS
                    refresh_workspace
                fi
                ;;
        esac
    done < <($CMUX events \
        --after "$latest_seq" \
        --category window \
        --category workspace \
        --reconnect \
        2>>"$log_file")

    # Capturar y reapear el proceso del process substitution.
    # En bash 3.2, $! después de < <(...) es el PID del proceso dentro del <(...).
    CMUX_EVENTS_PID=$!
    if [[ -n "$CMUX_EVENTS_PID" ]] && kill -0 "$CMUX_EVENTS_PID" 2>/dev/null; then
        kill "$CMUX_EVENTS_PID" 2>/dev/null || true
        wait "$CMUX_EVENTS_PID" 2>/dev/null || true
    fi
    CMUX_EVENTS_PID=""

    # EOF del pipe: el stream se cortó (cmux reiniciado, socket muerto, etc.).
    # El env -u en el próximo ciclo garantiza que cmux re-descubra el socket nuevo.
    log "stream cerrado (EOF); backoff ${backoff}s antes de reconectar"
    sleep "$backoff"
    backoff=$(( backoff < max_backoff ? backoff * 2 : max_backoff ))
done
