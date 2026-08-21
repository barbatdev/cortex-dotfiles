# Usage: imgclip <image> copies a supported image to the macOS clipboard.
function imgclip
    set -l image "$argv[1]"

    if not test -f "$image"
        printf '❌ Archivo no encontrado: %s\n' "$image"
        return 1
    end

    set -l extension (string lower -- (string replace -r '^.*\.' '' -- "$image"))
    switch "$extension"
        case png jpg jpeg gif bmp tiff
            set -l resolved (path resolve "$image")
            command osascript -e "set the clipboard to (read (POSIX file \"$resolved\") as «class PNGf»)" 2>/dev/null
            or command osascript -e "set the clipboard to POSIX file \"$resolved\""
            printf '✓ Imagen copiada al clipboard: %s\n' (command basename "$image")
        case '*'
            printf '❌ Formato no soportado: %s\n' "$extension"
            return 1
    end
end
