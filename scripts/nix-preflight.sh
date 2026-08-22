#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
failures=0

pass() {
	printf 'PASS %s\n' "$1"
}

warn() {
	printf 'WARN %s\n' "$1"
}

fail() {
	printf 'FAIL %s\n' "$1"
	failures=$((failures + 1))
}

username="$(id -un)"
home_directory="$HOME"
host_os="$(uname -s)"
host_architecture="$(uname -m)"

if [[ -n "$username" ]]; then
	pass "Current username: $username"
else
	fail 'Current username is unavailable.'
fi

if [[ "$home_directory" == /* && -d "$home_directory" ]]; then
	pass "Current home directory: $home_directory"
else
	fail "HOME must be an existing absolute directory; received: $home_directory"
fi

if [[ "$host_os" == "Darwin" ]]; then
	pass 'Host platform: Darwin.'
else
	fail "W1 currently targets macOS; detected platform: $host_os"
fi

case "$host_architecture" in
arm64 | x86_64)
	pass "Supported macOS architecture: $host_architecture"
	;;
*)
	fail "Unsupported macOS architecture for W1: $host_architecture"
	;;
esac

if grep -Fq 'home-manager' "$repo_root/flake.nix"; then
	pass 'Home Manager is declared by this repository flake; no standalone home-manager command is required.'
else
	fail 'Home Manager is not declared by flake.nix.'
fi

if ! command -v nix >/dev/null 2>&1; then
	fail 'Nix is unavailable; install Nix outside this repository before the future bootstrap.'
else
	pass 'Nix is available.'

	if nix --extra-experimental-features 'nix-command flakes' flake metadata --no-write-lock-file --offline "$repo_root" >/dev/null 2>&1; then
		pass 'Flake features and the local lock/input metadata are ready for read-only evaluation.'

		if nix --extra-experimental-features 'nix-command flakes' eval --no-write-lock-file --offline --raw "$repo_root#homeConfigurations.jbarbat.activationPackage.drvPath" >/dev/null 2>&1; then
			pass 'Pure Home Manager configuration jbarbat is available through the flake input.'
		else
			fail 'Pure Home Manager configuration jbarbat cannot be evaluated locally; generate flake.lock during the future bootstrap, then retry.'
		fi
	else
		fail 'Flake metadata is not available offline; generate flake.lock during the future bootstrap, then retry.'
	fi
fi

fish_config="$home_directory/.config/fish"
local_fish_config="$fish_config/conf.d/99-local.fish"

if [[ -e "$fish_config" || -L "$fish_config" ]]; then
	warn "Future Fish config path exists and will remain unmanaged: $fish_config"
else
	pass "Future Fish config path is absent: $fish_config"
fi

if [[ -e "$local_fish_config" || -L "$local_fish_config" ]]; then
	warn "Future host-owned path exists and will remain unmanaged: $local_fish_config"
else
	pass "Reserved host-owned future path is absent: $local_fish_config"
fi

if [[ "$failures" -eq 0 ]]; then
	pass 'W1 readiness complete: this check made no host changes.'
	exit 0
fi

printf 'FAIL W1 readiness is incomplete: this check made no host changes.\n'
exit 1
