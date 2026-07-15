#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

TIMESTAMP=test
DRY_RUN=false
# shellcheck source=scripts/install-helpers.sh
source "$repo_root/scripts/install-helpers.sh"

new_target="$tmp_dir/new-target"
printf '%s\n' new > "$new_target"

regular="$tmp_dir/regular"
printf '%s\n' original > "$regular"
backup_if_exists "$regular" >/dev/null
[[ "$(<"$regular.bak_test")" == original ]]
create_symlink "$new_target" "$regular" >/dev/null
[[ "$(readlink "$regular")" == "$new_target" ]]

old_target="$tmp_dir/old-target"
printf '%s\n' old > "$old_target"
link="$tmp_dir/link"
ln -s "$old_target" "$link"
backup_if_exists "$link" >/dev/null
[[ -L "$link.bak_test" ]]
[[ "$(readlink "$link.bak_test")" == "$old_target" ]]
create_symlink "$new_target" "$link" >/dev/null

directory="$tmp_dir/directory"
mkdir -p "$directory"
printf '%s\n' marker > "$directory/marker"
backup_if_exists "$directory" >/dev/null
[[ -f "$directory.bak_test/marker" ]]
create_symlink "$new_target" "$directory" >/dev/null
[[ -L "$directory" ]]
[[ ! -e "$directory/new-target" ]]

blocked="$tmp_dir/blocked"
printf '%s\n' keep > "$blocked"
if create_symlink "$new_target" "$blocked" >/dev/null 2>&1; then
    echo "create_symlink accepted an unbacked destination" >&2
    exit 1
fi
[[ "$(<"$blocked")" == keep ]]

collision="$tmp_dir/collision"
printf '%s\n' original > "$collision"
printf '%s\n' existing > "$collision.bak_test"
if backup_if_exists "$collision" >/dev/null 2>&1; then
    echo "backup_if_exists accepted an existing backup path" >&2
    exit 1
fi
[[ "$(<"$collision")" == original ]]
[[ "$(<"$collision.bak_test")" == existing ]]
