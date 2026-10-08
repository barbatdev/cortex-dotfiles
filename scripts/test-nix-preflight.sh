#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
preflight="$repo_root/scripts/nix-preflight.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
	printf 'FAIL %s\n' "$1" >&2
	exit 1
}

assert_contains() {
	local expected="$1"
	local file="$2"

	grep -Fqx "$expected" "$file" || fail "expected output: $expected"
}

assert_not_contains() {
	local forbidden="$1"
	local file="$2"

	if grep -Fq -- "$forbidden" "$file"; then
		fail "forbidden W1 construct found in $file: $forbidden"
	fi
}

assert_pure_home_manager_configurations() {
	assert_contains '      mkHomeConfiguration = { username, homeDirectory, system }:' "$repo_root/flake.nix"
	assert_contains '      homeConfigurations.jbarbat = mkHomeConfiguration {' "$repo_root/flake.nix"
	assert_contains '        username = "jbarbat";' "$repo_root/flake.nix"
	assert_contains '        homeDirectory = "/Users/jbarbat";' "$repo_root/flake.nix"
	assert_contains '        system = "aarch64-darwin";' "$repo_root/flake.nix"
	assert_contains '      homeConfigurations.jbarbat-linux = mkHomeConfiguration {' "$repo_root/flake.nix"
	assert_contains '        homeDirectory = "/home/jbarbat";' "$repo_root/flake.nix"
	assert_contains '        system = "x86_64-linux";' "$repo_root/flake.nix"
	assert_contains '{ username, homeDirectory, system, pkgs, lib, ... }:' "$repo_root/nix/home.nix"
	assert_contains '  sharedFishFiles = {' "$repo_root/nix/home.nix"
	assert_contains '  darwinFishFiles = {' "$repo_root/nix/home.nix"
	assert_contains '    packages = lib.optionals pkgs.stdenv.isLinux [ pkgs.fish pkgs.starship ];' "$repo_root/nix/home.nix"
	assert_contains '    // sharedFishFiles // lib.optionalAttrs (!pkgs.stdenv.isLinux) darwinFishFiles;' "$repo_root/nix/home.nix"
	assert_contains '      - name: Check Nix Home Manager preflight contracts' "$repo_root/.github/workflows/ci.yml"
	grep -Fq 'La configuración pura para Linux es `homeConfigurations.jbarbat-linux`:' "$repo_root/README.md" ||
		fail 'README does not document the Linux Home Manager configuration'

	for forbidden in 'builtins.currentSystem' 'builtins.getEnv'; do
		assert_not_contains "$forbidden" "$repo_root/flake.nix"
	done

	for file in "$repo_root/scripts/nix-preflight.sh" "$repo_root/.github/workflows/ci.yml" "$repo_root/README.md"; do
		assert_not_contains '--impure' "$file"
	done
}

assert_linux_fish_exclusions() {
	local shared_sources
	local darwin_sources

	shared_sources="$(sed -n '/  sharedFishFiles = {/,/  };/p' "$repo_root/nix/home.nix")"
	darwin_sources="$(sed -n '/  darwinFishFiles = {/,/  };/p' "$repo_root/nix/home.nix")"

	for source in '_screenshots_dir.fish' '_screenshot_files.fish' '_time_ago.fish' 'ss.fish' 'last.fish' 'ssd.fish' 'imgclip.fish' 'ccclip.fish'; do
		if grep -Fq -- "$source" <<<"$shared_sources"; then
			fail "Linux Fish ownership must exclude $source"
		fi
		grep -Fq -- "$source" <<<"$darwin_sources" ||
			fail "Darwin Fish ownership must retain $source"
	done
}

make_fake_commands() {
	local bin_dir="$1"
	local fake_os="$2"
	local fake_architecture="$3"

	mkdir -p "$bin_dir"

	cat >"$bin_dir/id" <<'EOF'
#!/bin/sh
if [ "$1" = "-un" ]; then
    printf '%s\n' 'test-user'
fi
EOF

	cat >"$bin_dir/uname" <<EOF
#!/bin/sh
case "\$1" in
    -s) printf '%s\\n' '$fake_os' ;;
    -m) printf '%s\\n' '$fake_architecture' ;;
esac
EOF

	chmod +x "$bin_dir/id" "$bin_dir/uname"
}

run_preflight() {
	local home_dir="$1"
	local bin_dir="$2"
	local output="$3"

	HOME="$home_dir" PATH="$bin_dir:/usr/bin:/bin" bash "$preflight" >"$output" 2>&1
}

assert_pure_home_manager_configurations
assert_linux_fish_exclusions

missing_nix_home="$tmp_dir/missing-nix-home"
missing_nix_bin="$tmp_dir/missing-nix-bin"
missing_nix_output="$tmp_dir/missing-nix.out"
mkdir -p "$missing_nix_home" "$missing_nix_bin"
make_fake_commands "$missing_nix_bin" Darwin arm64

if run_preflight "$missing_nix_home" "$missing_nix_bin" "$missing_nix_output"; then
	fail 'preflight unexpectedly passed without nix'
fi
assert_contains 'FAIL Nix is unavailable; install Nix outside this repository before the future bootstrap.' "$missing_nix_output"
assert_contains 'PASS Home Manager is declared by this repository flake; no standalone home-manager command is required.' "$missing_nix_output"

ready_home="$tmp_dir/ready-home"
ready_bin="$tmp_dir/ready-bin"
ready_output="$tmp_dir/ready.out"
mkdir -p "$ready_home" "$ready_bin"
make_fake_commands "$ready_bin" Darwin arm64
cat >"$ready_bin/nix" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$NIX_FAKE_LOG"
printf '%s\n' '/nix/store/fake-home-manager-activation.drv'
EOF
chmod +x "$ready_bin/nix"

NIX_FAKE_LOG="$tmp_dir/nix.log" run_preflight "$ready_home" "$ready_bin" "$ready_output"
assert_contains 'PASS Nix is available.' "$ready_output"
assert_contains 'PASS Flake features and the local lock/input metadata are ready for read-only evaluation.' "$ready_output"
assert_contains 'PASS Pure Home Manager configuration jbarbat is available through the flake input.' "$ready_output"
grep -F -- '--no-write-lock-file' "$tmp_dir/nix.log" >/dev/null || fail 'preflight did not prevent lock writes'
grep -F -- '--offline' "$tmp_dir/nix.log" >/dev/null || fail 'preflight did not force offline evaluation'
grep -F -- '#homeConfigurations.jbarbat.activationPackage.drvPath' "$tmp_dir/nix.log" >/dev/null || fail 'preflight did not evaluate the explicit pure configuration'
if grep -F -- '--impure' "$tmp_dir/nix.log" >/dev/null; then
	fail 'preflight evaluated the configuration impurely'
fi

linux_home="$tmp_dir/linux-home"
linux_bin="$tmp_dir/linux-bin"
linux_output="$tmp_dir/linux.out"
mkdir -p "$linux_home" "$linux_bin"
make_fake_commands "$linux_bin" Linux x86_64
cp "$ready_bin/nix" "$linux_bin/nix"
NIX_FAKE_LOG="$tmp_dir/linux-nix.log" run_preflight "$linux_home" "$linux_bin" "$linux_output"
assert_contains 'PASS Host platform: Linux x86_64 (homeConfigurations.jbarbat-linux).' "$linux_output"
assert_contains 'PASS Pure Home Manager configuration jbarbat-linux is available through the flake input.' "$linux_output"
grep -F -- '#homeConfigurations.jbarbat-linux.activationPackage.drvPath' "$tmp_dir/linux-nix.log" >/dev/null || fail 'preflight did not evaluate the Linux configuration'

unsupported_home="$tmp_dir/unsupported-home"
unsupported_bin="$tmp_dir/unsupported-bin"
unsupported_output="$tmp_dir/unsupported.out"
mkdir -p "$unsupported_home" "$unsupported_bin"
make_fake_commands "$unsupported_bin" Linux aarch64
if run_preflight "$unsupported_home" "$unsupported_bin" "$unsupported_output"; then
	fail 'preflight unexpectedly passed on an unsupported Linux architecture'
fi
assert_contains 'FAIL Unsupported platform: Linux aarch64. Supported targets are Darwin arm64 and Linux x86_64.' "$unsupported_output"

mkdir -p "$ready_home/.config/fish/conf.d"
printf '%s\n' '# host-owned local configuration' >"$ready_home/.config/fish/conf.d/99-local.fish"
collision_output="$tmp_dir/collision.out"
NIX_FAKE_LOG="$tmp_dir/nix.log" run_preflight "$ready_home" "$ready_bin" "$collision_output"
assert_contains "WARN Future host-owned path exists and will remain unmanaged: $ready_home/.config/fish/conf.d/99-local.fish" "$collision_output"

printf '%s\n' 'nix preflight contract ok'
