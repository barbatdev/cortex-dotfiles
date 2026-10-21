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

# seed_file: tool-owned configs (gentle-ai refuses symlinks) are copied once.
# shellcheck source=scripts/seed-file.sh
source "$repo_root/scripts/seed-file.sh"
seed_src="$tmp_dir/seed-src"
printf '%s\n' seed > "$seed_src"

seed_absent="$tmp_dir/seed/absent.json"
seed_file "$seed_src" "$seed_absent" >/dev/null
[[ -f "$seed_absent" && ! -L "$seed_absent" && "$(<"$seed_absent")" == seed ]]

seed_link="$tmp_dir/seed-link.json"
ln -s "$seed_src" "$seed_link"
seed_file "$seed_src" "$seed_link" >/dev/null
[[ -f "$seed_link" && ! -L "$seed_link" && "$(<"$seed_link")" == seed ]]
[[ "$(<"$seed_src")" == seed ]]

seed_owned="$tmp_dir/seed-owned.json"
printf '%s\n' tool-edited > "$seed_owned"
seed_file "$seed_src" "$seed_owned" >/dev/null
[[ "$(<"$seed_owned")" == tool-edited ]]

seed_foreign="$tmp_dir/seed-foreign.json"
ln -s "$old_target" "$seed_foreign"
seed_file "$seed_src" "$seed_foreign" >/dev/null
[[ -L "$seed_foreign" && "$(readlink "$seed_foreign")" == "$old_target" ]]

DRY_RUN=true
seed_dry="$tmp_dir/seed-dry.json"
seed_file "$seed_src" "$seed_dry" >/dev/null
[[ ! -e "$seed_dry" ]]
DRY_RUN=false

echo "install symlink checks passed"
