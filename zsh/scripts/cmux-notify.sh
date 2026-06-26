#!/bin/zsh
# Hook para cmux: notifica cuando Claude Code necesita atención.
# Se invoca desde settings.json en el evento Notification.
# Recibe JSON por stdin con campos: title, message, notification_type.

input=$(cat)
if command -v jq >/dev/null 2>&1; then
    title=$(echo "$input" | jq -r '.title // "Claude Code"')
    body=$(echo "$input" | jq -r '.message // "Necesita atención"')
else
    title="Claude Code"
    body="Necesita atención"
fi

if command -v cmux >/dev/null 2>&1; then
    # env -u descarta el socket heredado del caller; cmux auto-descubre el socket vivo
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET cmux notify --title "$title" --body "$body"
elif [ -x "/Applications/cmux.app/Contents/Resources/bin/cmux" ]; then
    env -u CMUX_SOCKET_PATH -u CMUX_SOCKET /Applications/cmux.app/Contents/Resources/bin/cmux notify --title "$title" --body "$body"
fi
