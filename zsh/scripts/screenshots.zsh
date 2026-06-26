#region Screenshot Utilities
# Funciones para manejo de screenshots en macOS
# Configurable via $SCREENSHOTS_DIR en local/env.zsh

# Obtener directorio de screenshots
_screenshots_dir() {
    if [[ -n "$SCREENSHOTS_DIR" && -d "$SCREENSHOTS_DIR" ]]; then
        echo "$SCREENSHOTS_DIR"
        return
    fi
    # Fallback: directorio estándar macOS
    local default="$HOME/Screenshots"
    if [[ -d "$default" ]]; then
        echo "$default"
    else
        echo "$HOME/Desktop"
    fi
}

# Formatear tiempo relativo
_time_ago() {
    local file="$1"
    local now=$(date +%s)
    local mtime=$(stat -f %m "$file" 2>/dev/null || echo "$now")
    local diff=$(( now - mtime ))

    if (( diff < 60 )); then
        echo "justo ahora"
    elif (( diff < 3600 )); then
        echo "$(( diff / 60 ))m ago"
    elif (( diff < 86400 )); then
        echo "$(( diff / 3600 ))h ago"
    else
        echo "$(( diff / 86400 ))d ago"
    fi
}

# Listar últimos screenshots
ss() {
    local count="${1:-10}"
    local dir="$(_screenshots_dir)"

    if [[ ! -d "$dir" ]]; then
        echo "⚠️  Directorio no encontrado: $dir"
        echo "   Configurá SCREENSHOTS_DIR en local/env.zsh"
        return 1
    fi

    echo "\n📸 Últimos $count screenshots en: $dir\n"

    local i=1
    while IFS= read -r -d '' file; do
        local name=$(basename "$file")
        local size=$(du -sh "$file" 2>/dev/null | cut -f1)
        local ago="$(_time_ago "$file")"
        printf "  [%d] \033[1;37m%s\033[0m \033[90m(%s) — %s\033[0m\n" "$i" "$name" "$size" "$ago"
        (( i++ ))
        (( i > count )) && break
    done < <(find "$dir" -maxdepth 2 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" \) -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | tr '\n' '\0')

    echo "\n  Usá \033[1;33mlast\033[0m para obtener el path del último screenshot\n"
}

# Obtener el último screenshot
last() {
    local copy=false open=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--copy) copy=true ;;
            -o|--open) open=true ;;
        esac
        shift
    done

    local dir="$(_screenshots_dir)"
    local file
    file=$(find "$dir" -maxdepth 2 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" \) -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1)

    if [[ -z "$file" ]]; then
        echo "⚠️  No se encontraron screenshots en: $dir"
        return 1
    fi

    if $copy; then
        echo "$file" | pbcopy
        echo "✓ Path copiado: $(basename "$file")"
    elif $open; then
        open "$file"
        echo "✓ Abriendo: $(basename "$file")"
    else
        echo "$file"
    fi
}

# Abrir directorio de screenshots en Finder
ssd() {
    local dir="$(_screenshots_dir)"
    if [[ -d "$dir" ]]; then
        open "$dir"
    else
        echo "⚠️  Directorio no encontrado: $dir"
    fi
}

# Copiar imagen al clipboard (macOS)
imgclip() {
    local path="$1"

    if [[ ! -f "$path" ]]; then
        echo "❌ Archivo no encontrado: $path"
        return 1
    fi

    local ext="${path##*.}"
    ext="${ext:l}"

    case "$ext" in
        png|jpg|jpeg|gif|bmp|tiff)
            osascript -e "set the clipboard to (read (POSIX file \"$(realpath "$path")\") as «class PNGf»)" 2>/dev/null || \
            osascript -e "set the clipboard to POSIX file \"$(realpath "$path")\""
            echo "✓ Imagen copiada al clipboard: $(basename "$path")"
            ;;
        *)
            echo "❌ Formato no soportado: $ext"
            return 1
            ;;
    esac
}

#endregion
