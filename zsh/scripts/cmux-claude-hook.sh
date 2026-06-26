#!/bin/sh
# Hook para cmux: notifica a la sidebar el estado de la sesión Claude.
# Se invoca desde settings.json en los eventos SessionStart, Stop y SessionEnd.
# $1 = evento: session-start, stop, session-end

# Guard: si no estamos dentro de un workspace cmux, salir silenciosamente
[ -n "$CMUX_WORKSPACE_ID" ] || exit 0

# Encontrar el binario cmux — primero en PATH, luego en la ubicación estándar de la app
if command -v cmux > /dev/null 2>&1; then
  CMUX_BIN="cmux"
elif [ -x "/Applications/cmux.app/Contents/Resources/bin/cmux" ]; then
  CMUX_BIN="/Applications/cmux.app/Contents/Resources/bin/cmux"
else
  # Binario no encontrado — salir silenciosamente sin error
  exit 0
fi

case "$1" in
  session-start)
    # Notificar a cmux que la sesión arrancó; env -u descarta el socket heredado del caller
    # y fuerza a cmux a descubrir el socket vivo del proceso activo
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" claude-hook session-start

    # Guardar workspace ID keyed por directorio para que statusline.sh lo pueda leer
    # (statusline.sh no hereda env vars de Claude Code)
    SAFE_DIR=$(echo "$PWD" | tr '/' '_')
    echo "$CMUX_WORKSPACE_ID" > "/tmp/cmux_ws_${SAFE_DIR}"

    # Resetear caches de progreso y modelo para que la primera ejecución del statusline
    # siempre setee la barra (evita que el throttle bloquee el re-set post-clear)
    rm -f "/tmp/cmux_progress_${CMUX_WORKSPACE_ID}"
    rm -f "/tmp/cmux_model_${CMUX_WORKSPACE_ID}"
    ;;

  stop)
    # Claude terminó una tarea (puede ser Ctrl+C o fin de turno — sesión sigue activa)
    # Solo notificar el estado, NO limpiar la barra de progreso
    # env -u descarta el socket heredado del caller para evitar "Connection refused"
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" claude-hook stop > /dev/null 2>&1 || true
    ;;

  session-end)
    # Sesión cerrada definitivamente — limpiar progreso y modelo del sidebar
    # env -u descarta el socket heredado del caller para evitar "Connection refused" en el Stop hook
    # Se usa $CMUX_WORKSPACE_ID (no el focused) porque el target correcto es el workspace de
    # la sesión que cierra: el usuario pudo haber enfocado otro workspace antes del cierre,
    # y clear-progress/clear-status deben actuar sobre la sesión que termina, no sobre la focused.
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" claude-hook stop > /dev/null 2>&1 || true
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" clear-progress --workspace "$CMUX_WORKSPACE_ID" > /dev/null 2>&1 &
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET "$CMUX_BIN" clear-status claude_model --workspace "$CMUX_WORKSPACE_ID" > /dev/null 2>&1 &
    ;;

  *)
    exit 0
    ;;
esac
