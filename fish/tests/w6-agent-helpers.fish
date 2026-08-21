#!/usr/bin/env fish

set -l repo_root (cd (dirname (dirname (status filename))); and pwd)
set -g functions_dir "$repo_root/functions"
set -g workspace (mktemp -d)
test -n "$workspace"; or exit 1
function _cleanup_w6 --on-event fish_exit
    test -d "$workspace"; and rm -rf -- "$workspace"
end
function fail
    printf 'FAIL: %s\n' "$argv" >&2
    exit 1
end
function contains
    string match -q "*$argv[2]*" -- "$argv[1]"; or fail "$argv[3]"
end

set -g home "$workspace/home"
set -g bin "$workspace/bin"
set -g repo "$workspace/repo"
set -g target "$workspace/target dir"
set -g workspace_dir "$workspace/workspace dir"
mkdir -p "$home/dev" "$bin" "$repo" "$target" "$workspace_dir/sub dir"
printf '#!/bin/sh\nprintf "claude|%%s|cwd=%%s|stdin=" "$*" "$PWD" >> "$W6_LOG"\nwhile IFS= read -r line; do printf "%%s\\n" "$line" >> "$W6_LOG"; done\nprintf "\\n" >> "$W6_LOG"\nexit "${W6_CLAUDE_STATUS:-0}"\n' > "$bin/claude"
printf '#!/bin/sh\nprintf "opencode|%%s|cwd=%%s\\n" "$*" "$PWD" >> "$W6_LOG"\nexit "${W6_OPENCODE_STATUS:-0}"\n' > "$bin/opencode"
printf '#!/bin/sh\nprintf "pbcopy|" >> "$W6_LOG"\nwhile IFS= read -r line; do printf "%%s\\n" "$line" >> "$W6_LOG"; done\nprintf "\\n" >> "$W6_LOG"\nexit "${W6_PBCOPY_STATUS:-0}"\n' > "$bin/pbcopy"
printf '#!/bin/sh\nfor file; do while IFS= read -r line || [ -n "$line" ]; do printf "%%s\\n" "$line"; done < "$file"; done\n' > "$bin/cat"
printf '%s\n' '#!/bin/sh' 'for file; do' '  case "$file" in -*) continue ;; esac' '  i=0' '  while IFS= read -r line || [ -n "$line" ]; do' '    i=$((i + 1))' '    printf "%6s\\t%s\\n" "$i" "$line"' '  done < "$file"' 'done' > "$bin/nl"
chmod +x "$bin"/*
printf 'alpha\n' > "$target/code file.fish"
printf 'beta\n' > "$target/other.txt"
printf '' > "$target/empty.txt"

function run_w6
    env -i HOME="$home" PATH="$bin:/usr/bin:/bin" W6_LOG="$workspace/log" \
        W6_CLAUDE_STATUS="$W6_CLAUDE_STATUS" W6_OPENCODE_STATUS="$W6_OPENCODE_STATUS" W6_PBCOPY_STATUS="$W6_PBCOPY_STATUS" OPENCODE_DEFAULT_FLAGS="$OPENCODE_DEFAULT_FLAGS" WORKSPACE_DIR="$WORKSPACE_DIR" \
        /opt/homebrew/bin/fish --no-config -c 'set -gx fish_function_path $argv[1] $fish_function_path; cd "$argv[2]"; and $argv[3] $argv[4..-1]' \
        "$functions_dir" "$repo" $argv
end
function run_w6_unavailable
    env -i HOME="$home" PATH="/usr/bin:/bin" /opt/homebrew/bin/fish --no-config \
        -c 'set -gx fish_function_path $argv[1] $fish_function_path; cd "$argv[2]"; and $argv[3] $argv[4..-1]' \
        "$functions_dir" "$repo" $argv
end

printf '' > "$workspace/log"
run_w6 cc; or fail 'cc must use the current directory without arguments'
string match -q -- "claude|--dangerously-skip-permissions|cwd=$repo|stdin=" (string collect <"$workspace/log"); or fail 'cc default command order'
printf '' > "$workspace/log"
run_w6 cc "$target"; or fail 'cc must succeed'
set -l log (string collect <"$workspace/log")
string match -q -- "claude|--dangerously-skip-permissions|cwd=$target|stdin=" "$log"; or fail 'cc target command order'

printf '' > "$workspace/log"
run_w6 oc "$target"; or fail 'oc must succeed without defaults'
string match -q -- "opencode|--auto|cwd=$target" (string collect <"$workspace/log"); or fail 'oc default command order'
printf '' > "$workspace/log"
set -gx OPENCODE_DEFAULT_FLAGS (printf '%s\t%s\n%s' --model test --plain | string collect --no-trim-newlines)
run_w6 oc "$target"; or fail 'oc must tokenize shell whitespace in defaults'
string match -q -- "opencode|--auto --model test --plain|cwd=$target" (string collect <"$workspace/log"); or fail 'oc tokenizes defaults after one auto flag'
set -gx OPENCODE_DEFAULT_FLAGS '--model test --plain'
printf '' > "$workspace/log"
run_w6 ocb "$target"; or fail 'ocb must succeed'
string match -q -- "opencode|--auto --model test --plain|cwd=$target" (string collect <"$workspace/log"); or fail 'ocb forwards defaults after one auto flag'
set -e OPENCODE_DEFAULT_FLAGS
set -gx W6_OPENCODE_STATUS 24
run_w6 oc "$target" >/dev/null 2>&1; and fail 'opencode status must propagate'
set -e W6_OPENCODE_STATUS

printf '' > "$workspace/log"
run_w6 ccx 'initial context with spaces' "$target"; or fail 'ccx must succeed'
contains (string collect <"$workspace/log") "claude||cwd=$target|stdin=initial context with spaces" 'ccx forwards context through stdin'
if run_w6 ccx >"$workspace/ccx.out" 2>&1
    fail 'ccx without context must fail'
end
contains (string collect <"$workspace/ccx.out") 'Uso: ccx' 'ccx usage'

if run_w6 cc "$workspace/missing" >"$workspace/missing.out" 2>&1
    fail 'missing agent target must fail'
end
contains (string collect <"$workspace/missing.out") 'Directorio no encontrado' 'missing target error'
set -gx W6_CLAUDE_STATUS 23
run_w6 cc "$target" >/dev/null 2>&1; and fail 'claude status must propagate'
set -e W6_CLAUDE_STATUS
set -gx W6_CLAUDE_STATUS 25
run_w6 ccx context "$target" >/dev/null 2>&1; and fail 'ccx status must propagate'
set -e W6_CLAUDE_STATUS
if run_w6_unavailable cc "$target" >"$workspace/unavailable.out" 2>&1
    fail 'unavailable claude must fail'
end
contains (string collect <"$workspace/unavailable.out") 'Unknown command' 'unavailable claude error'

set -gx WORKSPACE_DIR ''
set -l ccd_default (run_w6 ccd)
contains "$ccd_default" "Navegando a: $home/dev" 'ccd default directory'
set -gx WORKSPACE_DIR "$workspace_dir"
set -l ccd_output (run_w6 ccd 'sub dir')
contains "$ccd_output" "Navegando a: $workspace_dir/sub dir" 'ccd uses workspace override'
source "$functions_dir/ccd.fish"
cd "$repo"
ccd 'sub dir' >/dev/null; or fail 'ccd must change the invoking Fish process directory'
test "$PWD" = "$workspace_dir/sub dir"; or fail 'ccd persists PWD in the invoking Fish process'
if run_w6 ccd missing >"$workspace/ccd.out" 2>&1
    fail 'ccd missing directory must fail'
end
contains (string collect <"$workspace/ccd.out") 'Directorio no encontrado' 'ccd validates target'
set -e WORKSPACE_DIR

printf '' > "$workspace/log"
run_w6 ccclip "$target/code file.fish" -n; or fail 'ccclip must copy content'
set log (string collect <"$workspace/log")
contains "$log" "pbcopy|```fish" 'ccclip fences extension'
contains "$log" "// File: $target/code file.fish" 'ccclip preserves spaced path'
contains "$log" '1	alpha' 'ccclip includes line numbers'
printf '' > "$workspace/log"
run_w6 ccclip "$target/code file.fish"; or fail 'ccclip must copy newline-terminated content'
set log (string collect <"$workspace/log")
set -l expected_fence (string join \n alpha '```' | string collect)
contains "$log" "$expected_fence" 'ccclip trims trailing linefeeds before the closing fence'
printf '' > "$workspace/log"
run_w6 ccclip "$target/empty.txt"; or fail 'ccclip must copy empty files'
printf '' > "$workspace/log"
run_w6 ccclip "$workspace/missing"; or fail 'ccclip empty context preserves successful clipboard status'
contains (string collect <"$workspace/log") 'pbcopy|' 'ccclip hands empty context to clipboard'
set -gx W6_PBCOPY_STATUS 31
run_w6 ccclip "$target/other.txt" >/dev/null 2>&1; and fail 'clipboard failure must propagate'
set -e W6_PBCOPY_STATUS
if run_w6 ccclip >"$workspace/clip.out" 2>&1
    fail 'ccclip without files must fail'
end
contains (string collect <"$workspace/clip.out") 'Uso: ccclip' 'ccclip usage'

for file in "$functions_dir/_cortex_resolve_target.fish" "$functions_dir/_cortex_run_agent.fish" "$functions_dir/ocb.fish" "$functions_dir/ccx.fish" "$functions_dir/ccd.fish" "$functions_dir/ccclip.fish"
    set -l source (string collect < "$file")
    string match -rqi -- '(dangerously-skip-permissions|bypass-permissions|skip-permissions|auto-approv|--yes)' "$source"; and fail "unexpected unsafe W6 source: $file"
end

printf 'PASS: Fish W6 agent helpers\n'
