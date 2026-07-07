#region Ports Helpers
# Helpers seguros para inspeccionar y liberar puertos de desarrollo.

# Mostrar procesos escuchando en un puerto.
# Uso: port <puerto>
port() {
    local port_number="${1:?Uso: port <puerto>}"

    if command -v lsof &>/dev/null; then
        lsof -nP -iTCP:"$port_number" -sTCP:LISTEN
    elif command -v ss &>/dev/null; then
        ss -ltnp "sport = :$port_number"
    else
        echo "No hay lsof ni ss disponibles para inspeccionar puertos."
        return 1
    fi
}

# Terminar procesos que escuchan en un puerto. Usa TERM por defecto; -9 fuerza KILL.
# Uso: killport [-9] <puerto>
killport() {
    local signal="TERM"
    if [[ "${1:-}" == "-9" ]]; then
        signal="KILL"
        shift
    fi

    local port_number="${1:?Uso: killport [-9] <puerto>}"
    local pids=""

    if command -v lsof &>/dev/null; then
        pids="$(lsof -tiTCP:"$port_number" -sTCP:LISTEN 2>/dev/null)"
    elif command -v fuser &>/dev/null; then
        pids="$(fuser "${port_number}/tcp" 2>/dev/null)"
    else
        echo "No hay lsof ni fuser disponibles para liberar puertos."
        return 1
    fi

    if [[ -z "$pids" ]]; then
        echo "Nada escuchando en el puerto $port_number"
        return 0
    fi

    echo "$pids" | xargs kill -s "$signal"
    echo "Procesos en puerto $port_number terminados con SIG$signal: $pids"
}

# Listar listeners de desarrollo comunes en host local.
# Uso: devports
devports() {
    local ports=(3000 3001 4200 5173 8000 8080 8090 8443)

    if command -v lsof &>/dev/null; then
        lsof -nP $(printf -- '-iTCP:%s ' "${ports[@]}") -sTCP:LISTEN
    elif command -v ss &>/dev/null; then
        ss -ltnp
    else
        echo "No hay lsof ni ss disponibles para listar puertos."
        return 1
    fi
}
#endregion
