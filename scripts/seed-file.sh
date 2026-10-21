#!/bin/bash

# seed_file SRC DST — install a config that another tool owns after first run.
# Some managers (gentle-ai sync) refuse to read or write symlinks, so these
# files are copied, never linked:
#   - absent DST: copy SRC
#   - DST is our old symlink to SRC: replace it with a regular copy
#   - DST is a regular file: keep it; the owning tool may have edited it
#   - DST is a symlink elsewhere: keep it and warn
seed_file() {
    local src="$1"
    local dst="$2"

    if [[ -L "$dst" && "$(readlink "$dst")" != "$src" ]]; then
        echo "  ! $dst is a foreign symlink; left untouched" >&2
        return 0
    fi
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        echo "  = $dst kept (tool-owned)"
        return 0
    fi
    if [[ "$DRY_RUN" == true ]]; then
        echo "  → Would seed $dst from $src"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    local tmp
    tmp="$(mktemp "$dst.seed.XXXXXX")"
    cp "$src" "$tmp"
    # mktemp creates 0600; configs are world-readable like a plain cp.
    chmod 0644 "$tmp"
    # mv over a symlink replaces the link itself, never its target.
    mv -f "$tmp" "$dst"
    echo "  ✓ $dst seeded from $src"
}
