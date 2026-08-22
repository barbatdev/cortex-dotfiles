#!/usr/bin/env fish

set -l repo_root (cd (dirname (dirname (status filename))); and pwd)
set -g function_file "$repo_root/functions/hremote.fish"
set -g workspace (mktemp -d)
if test -z "$workspace"
    printf 'FAIL: could not create temporary workspace\n' >&2
    exit 1
end

function _cleanup_workspace --on-event fish_exit
    test -d "$workspace"; and rm -rf -- "$workspace"
end

function fail
    printf 'FAIL: %s\n' "$argv" >&2
    exit 1
end

set -g fish_bin (status fish-path); and test -n "$fish_bin"; or fail 'could not resolve Fish interpreter'
function run_hremote
    set -l bin_dir "$argv[1]"
    set -e argv[1]
    env HOME="$workspace/home" PATH="$bin_dir:/usr/bin:/bin" "$fish_bin" --no-config \
        -c 'source $argv[1]; hremote $argv[2..-1]' "$function_file" $argv
end

set -l empty_bin "$workspace/empty-bin"
set -l fake_bin "$workspace/fake-bin"
mkdir -p "$workspace/home" "$empty_bin" "$fake_bin"

if run_hremote "$empty_bin" >"$workspace/missing-target.out" 2>&1
    fail 'missing target must fail'
end
set -l missing_target_output (string collect <"$workspace/missing-target.out")
string match -q '*Usage: hremote <ssh-target> [session]*' "$missing_target_output"; or fail "missing target usage: $missing_target_output"

if run_hremote "$empty_bin" agent-dev >"$workspace/missing-herdr.out" 2>&1
    fail 'missing herdr must fail'
end
set -l missing_herdr_output (string collect <"$workspace/missing-herdr.out")
string match -q '*hremote: herdr is not available*' "$missing_herdr_output"; or fail "missing herdr error: $missing_herdr_output"

printf '%s\n' '#!/bin/sh' 'printf "%s|%s|%s\n" "$CORTEX_MULTIPLEXER" "$CORTEX_SSH_TARGET" "$*"' >"$fake_bin/herdr"
chmod +x "$fake_bin/herdr"

set -l default_output (run_hremote "$fake_bin" agent-dev)
test "$default_output" = 'herdr|agent-dev|--remote agent-dev --session main'; or fail 'default remote session contract'

set -l explicit_output (run_hremote "$fake_bin" agent-dev focus)
test "$explicit_output" = 'herdr|agent-dev|--remote agent-dev --session focus'; or fail 'explicit remote session contract'

printf 'PASS: Fish hremote parity\n'
