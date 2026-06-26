#region PCSoft Helpers
# Funciones de detección y protección de archivos PCSoft
# Relevante cuando se trabaja con archivos del repositorio de la PC Windows

# Categoría B: archivos que NUNCA se modifican externamente
PCSOFT_FORBIDDEN_EXTENSIONS=(
    wdp wwp wpp wpj      # Proyectos
    wwh wpw              # Páginas WebDev/Mobile
    prw                  # Procedimientos individuales
    wdd fic mmo ndx      # Modelo de datos / HFSQL
    wdr wdq              # Reportes / Queries
    wdi wdt wdv wdk      # Componentes
    rep sty cpl bkp tk cfg  # Config / Build
)

# Categoría A: archivos editables externamente (SOLO bloques 'code : |1+', IDE cerrado)
PCSOFT_EDITABLE_EXTENSIONS=(
    wdg   # Colecciones de procedimientos
    wdc   # Clases
    wde   # Reportes con código editable
    wdw   # Ventanas (solo eventos, NO internal_properties)
)

# Verifica si un archivo es Categoría B (prohibido modificar)
is-pcsoft-forbidden() {
    local ext="${1##*.}"
    ext="${ext:l}"  # lowercase
    for forbidden in "${PCSOFT_FORBIDDEN_EXTENSIONS[@]}"; do
        [[ "$ext" == "$forbidden" ]] && return 0
    done
    return 1
}

# Verifica si un archivo es Categoría A (editable con restricciones)
is-pcsoft-editable() {
    local ext="${1##*.}"
    ext="${ext:l}"  # lowercase
    for editable in "${PCSOFT_EDITABLE_EXTENSIONS[@]}"; do
        [[ "$ext" == "$editable" ]] && return 0
    done
    return 1
}

#endregion
