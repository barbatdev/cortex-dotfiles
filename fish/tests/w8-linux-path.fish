#!/usr/bin/env fish
# Linux hosts share one 10-core.fish: every tool directory any host uses is
# listed once and added only when it exists, so no host edits its own copy.
# macOS keeps the `o` alias; Linux has no `open`, so the alias is absent.

set -l repo_root (cd (dirname (dirname (status filename))); and pwd)
set -l core "$repo_root/conf.d/10-core.fish"
set -l fish_bin (status fish-path)
set -l ws (mktemp -d)

function fail
    printf 'FAIL: %s\n' "$argv" >&2
    exit 1
end

set -l home "$ws/home"
set -l fake "$ws/fake"
mkdir -p "$fake"
printf '#!/bin/sh\necho Linux\n' >"$fake/uname"
chmod +x "$fake/uname"

# Prefixed with $home so the test never depends on the runner's real dirs.
set -l dirs .pi/agent/bin .local/go-1.27.1/bin .bun/bin .local/share/pnpm/bin .nix-profile/bin .opencode/bin .local/bin
for d in $dirs
    mkdir -p "$home/$d"
end

set -l probe 'source $argv[1]; string join "|" $PATH; functions -q o; and echo o=defined; or echo o=absent'
set -l out (env -i HOME="$home" PATH="$fake:/usr/bin:/bin" "$fish_bin" --no-config -c "$probe" "$core")

# fish_add_path --move prepends in loop order: the last listed dir ends first.
# Only entries under the fake HOME: system dirs like /nix differ per runner.
set -l ours (string join '|' (string match -- "$home/*" (string split '|' -- $out[1])))
set -l expected "$home/.local/bin|$home/.opencode/bin|$home/.nix-profile/bin|$home/.local/share/pnpm/bin|$home/.bun/bin|$home/.local/go-1.27.1/bin|$home/.pi/agent/bin"
test "$ours" = "$expected"; or fail "Linux PATH order (expected $expected, got $ours)"
string match -q -- "$home/.local/bin|*" "$out[1]"; or fail "user-local bin must lead PATH ($out[1])"
test "$out[2]" = o=absent; or fail "Linux must not define the macOS open alias ($out[2])"

# Absent dirs are skipped, not added.
set -l bare "$ws/bare"
mkdir -p "$bare"
set -l out_bare (env -i HOME="$bare" PATH="$fake:/usr/bin:/bin" "$fish_bin" --no-config -c "$probe" "$core")
string match -q -- "*$bare*" "$out_bare[1]"; and fail "missing dirs were added to PATH: $out_bare[1]"

# macOS: 10-core.fish owns PATH too (config.fish no longer edits it).
printf '#!/bin/sh\necho Darwin\n' >"$fake/uname"
set -l mac "$ws/mac"
set -l mac_dirs .pi/agent/bin .cargo/bin .local/bin .opencode/bin .volta/bin .bun/bin .nix-profile/bin .gentle-ai/bin
for d in $mac_dirs
    mkdir -p "$mac/$d"
end
set -l out_mac (env -i HOME="$mac" PATH="$fake:/usr/bin:/bin" "$fish_bin" --no-config -c "$probe" "$core")
test "$out_mac[2]" = o=defined; or fail "macOS must define the open alias ($out_mac[2])"
set -l mac_ours (string join '|' (string match -- "$mac/*" (string split '|' -- $out_mac[1])))
set -l mac_expected "$mac/.gentle-ai/bin|$mac/.cargo/bin|$mac/.local/bin|$mac/.opencode/bin|$mac/.volta/bin|$mac/.bun/bin|$mac/.nix-profile/bin|$mac/.pi/agent/bin"
test "$mac_ours" = "$mac_expected"; or fail "macOS PATH order (expected $mac_expected, got $mac_ours)"
string match -q -- "$mac/.gentle-ai/bin|*" "$out_mac[1]"; or fail "gentle-ai launchers must lead the macOS PATH ($out_mac[1])"

rm -rf -- "$ws"
printf 'linux path checks passed\n'
