#!/bin/bash

backup_if_exists() {
    local src="$1"
    if [[ -e "$src" || -L "$src" ]]; then
        local backup="${src}.bak_${TIMESTAMP}"
        if [[ "$DRY_RUN" == true ]]; then
            echo "  → Would backup $src to $backup"
        else
            if [[ -e "$backup" || -L "$backup" ]]; then
                echo "  ✗ Backup existente: $backup" >&2
                return 1
            fi
            mv "$src" "$backup"
            echo "  → Backup: $backup"
        fi
    fi
}

create_symlink() {
    local src="$1"
    local dst="$2"
    if [[ "$DRY_RUN" == true ]]; then
        echo "  → Would symlink $dst → $src"
    else
        mkdir -p "$(dirname "$dst")"
        if [[ -e "$dst" || -L "$dst" ]]; then
            echo "  ✗ Destino existente sin backup: $dst" >&2
            return 1
        fi
        ln -s "$src" "$dst"
        [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]] || return 1
        echo "  ✓ $dst → $src"
    fi
}
