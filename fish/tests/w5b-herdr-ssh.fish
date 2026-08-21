#!/usr/bin/env fish
set -l repo_root (cd (dirname (dirname (status filename))); and pwd)
set -g functions_dir "$repo_root/functions"
set -g workspace (mktemp -d)
test -n "$workspace"; or exit 1
function _cleanup_workspace --on-event fish_exit
    test -d "$workspace"; and rm -rf -- "$workspace"
end
function fail
    printf 'FAIL: %s\n' "$argv" >&2
    exit 1
end
function assert_equal
    test "$argv[1]" = "$argv[2]"; or fail "$argv[3] (expected '$argv[2]', got '$argv[1]')"
end
function run_function
    set -l bin_dir "$argv[1]"
    set -e argv[1]
    env HOME="$workspace/home" PATH="$bin_dir:/usr/bin:/bin" TMPDIR="$workspace/tmp" \
        HERDR_TEST_LOG="$workspace/herdr.log" /opt/homebrew/bin/fish --no-config \
        -c 'set -gx fish_function_path $argv[1]; $argv[2] $argv[3..-1]' "$functions_dir" $argv
end
set -l empty_bin "$workspace/empty-bin"
set -l fake_bin "$workspace/fake-bin"
mkdir -p "$workspace/home" "$workspace/tmp" "$workspace/project" "$empty_bin" "$fake_bin"
set -l resolved_project (cd "$workspace/project"; and pwd -P)
if run_function "$empty_bin" hhere "$workspace/project" >"$workspace/missing-herdr.out" 2>&1
    fail 'hhere without herdr must fail'
end
set -l missing_herdr (string collect <"$workspace/missing-herdr.out")
string match -q '*hhere: herdr is not available*' "$missing_herdr"; or fail "hhere missing herdr: $missing_herdr"
printf '%s\n' '#!/bin/sh' 'printf "herdr|%s|%s|%s\n" "$CORTEX_MULTIPLEXER" "$CORTEX_SSH_TARGET" "$*" >> "$HERDR_TEST_LOG"' 'case "$1 $2" in' '  "workspace list") printf "{\"result\":{\"workspaces\":[]}}\n" ;;' 'esac' >"$fake_bin/herdr"
printf '%s\n' '#!/bin/sh' 'if [ -n "$HERDR_TEST_WORKSPACE_ID" ]; then printf "%s\n" "$HERDR_TEST_WORKSPACE_ID"; elif [ -n "$HERDR_TEST_PANE_ID" ]; then printf "%s\n" "$HERDR_TEST_PANE_ID"; fi' >"$fake_bin/python3"
printf '%s\n' '#!/bin/sh' 'printf "ssh|%s|%s\n" "$CORTEX_SSH_TARGET" "$*" >> "$HERDR_TEST_LOG"' '[ "$1" = -G ] && exit 0' 'exit 99' >"$fake_bin/ssh"
printf '%s\n' '#!/bin/sh' 'printf "cmux|%s|%s\n" "$CORTEX_SSH_TARGET" "$*" >> "$HERDR_TEST_LOG"' >"$fake_bin/cmux"
printf '%s\n' '#!/bin/sh' 'printf "testhost\n"' >"$fake_bin/hostname"
printf '%s\n' '#!/bin/sh' 'printf "123456\n"' >"$fake_bin/date"
chmod +x "$fake_bin/herdr" "$fake_bin/python3" "$fake_bin/ssh" "$fake_bin/cmux" "$fake_bin/hostname" "$fake_bin/date"
set -l local_output (run_function "$fake_bin" hhere "$workspace/project")
test -z "$local_output"; or fail "hhere outer output: $local_output"
set -l herdr_log (string collect <"$workspace/herdr.log")
string match -q "*herdr|herdr||--session local-testhost-project*" "$herdr_log"; or fail "local session: $herdr_log"
printf '' >"$workspace/herdr.log"
env HOME="$workspace/home" PATH="$fake_bin:/usr/bin:/bin" TMPDIR="$workspace/tmp" HERDR_TEST_LOG="$workspace/herdr.log" /opt/homebrew/bin/fish --no-config -c 'set -gx fish_function_path $argv[1]; cd $argv[2]; hhere' "$functions_dir" "$workspace/project"
set herdr_log (string collect <"$workspace/herdr.log")
string match -q "*--session local-testhost-project*" "$herdr_log"; or fail "default hhere session: $herdr_log"
printf '' >"$workspace/herdr.log"
set -l focus_output (env HERDR_ENV=1 HERDR_TEST_WORKSPACE_ID=workspace-42 HOME="$workspace/home" PATH="$fake_bin:/usr/bin:/bin" TMPDIR="$workspace/tmp" HERDR_TEST_LOG="$workspace/herdr.log" /opt/homebrew/bin/fish --no-config -c 'set -gx fish_function_path $argv[1]; hfocus $argv[2]' "$functions_dir" "$workspace/project")
assert_equal "$focus_output" 'workspace: project-focus' 'existing workspace focus output'
set herdr_log (string collect <"$workspace/herdr.log")
string match -q '*workspace list*' "$herdr_log"; or fail "workspace list: $herdr_log"
string match -q '*workspace focus workspace-42*' "$herdr_log"; or fail "workspace focus: $herdr_log"
printf '' >"$workspace/herdr.log"
set -l scratch_output (env HERDR_ENV=1 HOME="$workspace/home" PATH="$fake_bin:/usr/bin:/bin" TMPDIR="$workspace/tmp" HERDR_TEST_LOG="$workspace/herdr.log" /opt/homebrew/bin/fish --no-config -c 'set -gx fish_function_path $argv[1]; hscratch $argv[2]' "$functions_dir" "$workspace/project")
assert_equal "$scratch_output" 'workspace: project-scratch' 'new workspace output'
set herdr_log (string collect <"$workspace/herdr.log")
string match -q "*workspace create --cwd $resolved_project --label project-scratch --focus*" "$herdr_log"; or fail "workspace create: $herdr_log"
if run_function "$fake_bin" hrole >"$workspace/hrole.out" 2>&1
    fail 'hrole without role must fail'
end
string match -q '*Uso: hrole <rol> [path]*' (string collect <"$workspace/hrole.out"); or fail 'hrole usage'
if run_function "$fake_bin" hhere "$workspace/missing" >"$workspace/path.out" 2>&1
    fail 'missing path must fail'
end
string match -q "*Directorio no encontrado: $workspace/missing*" (string collect <"$workspace/path.out"); or fail 'missing path error'
printf '' >"$workspace/herdr.log"
run_function "$fake_bin" sshc agent-dev -p 22
set herdr_log (string collect <"$workspace/herdr.log")
assert_equal "$herdr_log" 'ssh|agent-dev|agent-dev -p 22' 'sshc routing'
printf '' >"$workspace/herdr.log"
run_function "$fake_bin" sshx agent-dev -o StrictHostKeyChecking=no
set herdr_log (string collect <"$workspace/herdr.log")
assert_equal "$herdr_log" 'cmux|agent-dev|ssh agent-dev -o StrictHostKeyChecking=no' 'sshx routing'
printf '' >"$workspace/herdr.log"
run_function "$fake_bin" sshx-doctor agent-dev; or fail 'sshx-doctor success'
set herdr_log (string collect <"$workspace/herdr.log")
assert_equal "$herdr_log" 'ssh||-G agent-dev' 'sshx-doctor must only resolve config'
printf '' >"$workspace/herdr.log"
set -l rename_output (env HERDR_TEST_PANE_ID=pane-1 HOME="$workspace/home" PATH="$fake_bin:/usr/bin:/bin" TMPDIR="$workspace/tmp" HERDR_TEST_LOG="$workspace/herdr.log" /opt/homebrew/bin/fish --no-config -c 'set -gx fish_function_path $argv[1]; hname review' "$functions_dir")
assert_equal "$rename_output" 'pane: review' 'hname output'
set herdr_log (string collect <"$workspace/herdr.log")
string match -q '*pane rename pane-1 review*' "$herdr_log"; or fail "hname routing: $herdr_log"
if run_function "$fake_bin" sshc -bad >"$workspace/invalid.out" 2>&1
    fail 'invalid ssh target must fail'
end
string match -q '*Target SSH inválido: -bad*' (string collect <"$workspace/invalid.out"); or fail 'invalid ssh target error'
if run_function "$empty_bin" sshx agent-dev >"$workspace/missing-cmux.out" 2>&1
    fail 'missing cmux must fail'
end
string match -q '*cmux no está disponible*' (string collect <"$workspace/missing-cmux.out"); or fail 'missing cmux error'
if env HOME="$workspace/home" PATH="$empty_bin" TMPDIR="$workspace/tmp" /opt/homebrew/bin/fish --no-config -c 'set -gx fish_function_path $argv[1]; sshc agent-dev' "$functions_dir" >"$workspace/missing-ssh.out" 2>&1
    fail 'missing ssh must fail'
end
string match -q '*sshc: ssh is not available*' (string collect <"$workspace/missing-ssh.out"); or fail 'missing ssh error'
if env HOME="$workspace/home" PATH="$empty_bin" TMPDIR="$workspace/tmp" /opt/homebrew/bin/fish --no-config -c 'set -gx fish_function_path $argv[1]; sshx-doctor agent-dev' "$functions_dir" >"$workspace/doctor-missing.out" 2>&1
    fail 'doctor without tools must fail'
end
set -l doctor_missing (string collect <"$workspace/doctor-missing.out")
string match -q '*cmux no encontrado*' "$doctor_missing"; and string match -q '*ssh no encontrado*' "$doctor_missing"; or fail 'doctor missing tools'
printf 'PASS: Fish W5b Herdr and SSH parity\n'
