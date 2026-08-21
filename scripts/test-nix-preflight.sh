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

assert_pure_w1_configuration() {
	assert_contains '      mkHomeConfiguration = { username, homeDirectory, system }:' "$repo_root/flake.nix"
	assert_contains '      homeConfigurations.jbarbat = mkHomeConfiguration {' "$repo_root/flake.nix"
	assert_contains '        username = "jbarbat";' "$repo_root/flake.nix"
	assert_contains '        homeDirectory = "/Users/jbarbat";' "$repo_root/flake.nix"
	assert_contains '        system = "aarch64-darwin";' "$repo_root/flake.nix"
	assert_contains '{ username, homeDirectory, system, ... }:' "$repo_root/nix/home.nix"
	assert_contains '      - name: Check pure Nix preflight contract' "$repo_root/.github/workflows/ci.yml"
	grep -Fq 'La configuración pura de W1 es `homeConfigurations.jbarbat`:' "$repo_root/README.md" ||
		fail 'README does not document the pure W1 configuration'

	for forbidden in 'home.packages' 'programs.fish' 'services.' 'home.activation'; do
		assert_not_contains "$forbidden" "$repo_root/nix/home.nix"
	done

	assert_not_contains 'builtins.currentSystem' "$repo_root/flake.nix"
	assert_not_contains 'builtins.getEnv' "$repo_root/flake.nix"

	for file in "$repo_root/scripts/nix-preflight.sh" "$repo_root/.github/workflows/ci.yml" "$repo_root/README.md"; do
		assert_not_contains '--impure' "$file"
	done
}

make_fake_commands() {
	local bin_dir="$1"

	mkdir -p "$bin_dir"

	cat >"$bin_dir/id" <<'EOF'
#!/bin/sh
if [ "$1" = "-un" ]; then
    printf '%s\n' 'test-user'
fi
EOF

	cat >"$bin_dir/uname" <<'EOF'
#!/bin/sh
case "$1" in
    -s) printf '%s\n' 'Darwin' ;;
    -m) printf '%s\n' 'arm64' ;;
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

assert_pure_w1_configuration

missing_nix_home="$tmp_dir/missing-nix-home"
missing_nix_bin="$tmp_dir/missing-nix-bin"
missing_nix_output="$tmp_dir/missing-nix.out"
mkdir -p "$missing_nix_home" "$missing_nix_bin"
make_fake_commands "$missing_nix_bin"

if run_preflight "$missing_nix_home" "$missing_nix_bin" "$missing_nix_output"; then
	fail 'preflight unexpectedly passed without nix'
fi
assert_contains 'FAIL Nix is unavailable; install Nix outside this repository before the future bootstrap.' "$missing_nix_output"
assert_contains 'PASS Home Manager is declared by this repository flake; no standalone home-manager command is required.' "$missing_nix_output"

ready_home="$tmp_dir/ready-home"
ready_bin="$tmp_dir/ready-bin"
ready_output="$tmp_dir/ready.out"
mkdir -p "$ready_home" "$ready_bin"
make_fake_commands "$ready_bin"
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

mkdir -p "$ready_home/.config/fish/conf.d"
printf '%s\n' '# host-owned local configuration' >"$ready_home/.config/fish/conf.d/99-local.fish"
collision_output="$tmp_dir/collision.out"
NIX_FAKE_LOG="$tmp_dir/nix.log" run_preflight "$ready_home" "$ready_bin" "$collision_output"
assert_contains "WARN Future host-owned path exists and will remain unmanaged: $ready_home/.config/fish/conf.d/99-local.fish" "$collision_output"

printf '%s\n' 'nix preflight contract ok'
