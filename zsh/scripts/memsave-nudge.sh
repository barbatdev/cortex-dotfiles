#!/bin/sh
# Hook UserPromptSubmit: recuerda guardar contexto en work-brain cada 15 minutos.
# Si pasaron +15 min desde el último nudge y la sesión tiene +5 min, inyecta recordatorio.

SESSION_ID="${CLAUDE_SESSION_ID:-$$}"
SESSION_FILE="/tmp/claude-nudge-${SESSION_ID}-start"
NUDGE_FILE="/tmp/claude-nudge-${SESSION_ID}-last"
NOW=$(date +%s)

# Primer mensaje de la sesión: registrar inicio y salir sin nudge
if [ ! -f "$SESSION_FILE" ]; then
    echo "$NOW" > "$SESSION_FILE"
    exit 0
fi

SESSION_START=$(cat "$SESSION_FILE" 2>/dev/null || echo "$NOW")
SESSION_AGE=$((NOW - SESSION_START))

# Sesión menor a 5 minutos → no nudge todavía
[ "$SESSION_AGE" -lt 300 ] && exit 0

# Último nudge hace menos de 15 minutos → no repetir
if [ -f "$NUDGE_FILE" ]; then
    LAST_NUDGE=$(cat "$NUDGE_FILE")
    TIME_SINCE=$((NOW - LAST_NUDGE))
    [ "$TIME_SINCE" -lt 900 ] && exit 0
fi

# Registrar timestamp del nudge
echo "$NOW" > "$NUDGE_FILE"

# Inyectar recordatorio como additionalContext
printf '%s\n' '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "RECORDATORIO: Llevas más de 15 minutos sin guardar en work-brain. Si tomaste decisiones, resolviste algo no obvio, o completaste trabajo significativo, guardalo ahora con mem_save antes de continuar."
  }
}'
