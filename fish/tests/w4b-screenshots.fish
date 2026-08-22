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

set -g fish_bin (status fish-path); and test -n "$fish_bin"; or fail 'could not resolve Fish interpreter'
function assert_equal
    test "$argv[1]" = "$argv[2]"; or fail "$argv[3] (expected '$argv[2]', got '$argv[1]')"
end

function assert_contains
    string match -q "*$argv[2]*" "$argv[1]"; or fail "$argv[3] (missing '$argv[2]')"
end

function run_function
    set -l bin_dir "$argv[1]"
    set -e argv[1]
    set -l isolated_home "$workspace/home"
    test -n "$W4B_HOME"; and set isolated_home "$W4B_HOME"
    env -i HOME="$isolated_home" PATH="$bin_dir:/usr/bin:/bin" \
        W4B_LOG="$workspace/commands.log" \
        W4B_SCREENSHOTS_DIR="$W4B_SCREENSHOTS_DIR" \
        W4B_OSASCRIPT_FAIL_FIRST="$W4B_OSASCRIPT_FAIL_FIRST" \
        W4B_OSASCRIPT_SEEN="$workspace/osascript.seen" \
        "$fish_bin" --no-config \
        -c 'set -gx fish_function_path $argv[1] $fish_function_path; if test -n "$W4B_SCREENSHOTS_DIR"; set -gx SCREENSHOTS_DIR "$W4B_SCREENSHOTS_DIR"; else; set -e SCREENSHOTS_DIR; end; $argv[2] $argv[3..-1]' \
        "$functions_dir" $argv
end

set -l fake_bin "$workspace/fake-bin"
set -l empty_bin "$workspace/empty-bin"
set -l home "$workspace/home"
set -l screenshots "$home/Screenshots"
set -l override "$workspace/override"
mkdir -p "$fake_bin" "$empty_bin" "$screenshots/nested/deeper" "$override"

printf '%s\n' '#!/bin/sh' 'printf "date|%s\n" "$*" >> "$W4B_LOG"' 'printf "1000\n"' >"$fake_bin/date"
printf '%s\n' '#!/bin/sh' 'printf "stat" >> "$W4B_LOG"' 'for arg in "$@"; do printf "|%s" "$arg" >> "$W4B_LOG"; done' 'printf "\n" >> "$W4B_LOG"' 'printf "995\n"' >"$fake_bin/stat"
printf '%s\n' '#!/bin/sh' 'printf "open" >> "$W4B_LOG"' 'for arg in "$@"; do printf "|%s" "$arg" >> "$W4B_LOG"; done' 'printf "\n" >> "$W4B_LOG"' >"$fake_bin/open"
printf '%s\n' '#!/bin/sh' 'input=$(cat)' 'printf "pbcopy|%s\n" "$input" >> "$W4B_LOG"' >"$fake_bin/pbcopy"
printf '%s\n' '#!/bin/sh' 'printf "osascript" >> "$W4B_LOG"' 'for arg in "$@"; do printf "|%s" "$arg" >> "$W4B_LOG"; done' 'printf "\n" >> "$W4B_LOG"' 'if [ "$W4B_OSASCRIPT_FAIL_FIRST" = 1 ] && [ ! -e "$W4B_OSASCRIPT_SEEN" ]; then : > "$W4B_OSASCRIPT_SEEN"; exit 1; fi' >"$fake_bin/osascript"
printf '%s\n' '#!/bin/sh' 'printf "screencapture|%s\n" "$*" >> "$W4B_LOG"' >"$fake_bin/screencapture"
printf '%s\n' '#!/bin/sh' 'printf "pngpaste|%s\n" "$*" >> "$W4B_LOG"' >"$fake_bin/pngpaste"
chmod +x "$fake_bin"/*

printf 'old\n' >"$screenshots/older.png"
printf 'new\n' >"$screenshots/newer.jpg"
printf 'nested\n' >"$screenshots/nested/latest.gif"
printf 'deep\n' >"$screenshots/nested/deeper/too-deep.png"
printf 'ignored\n' >"$screenshots/ignored.txt"
printf 'override\n' >"$override/override.png"
/usr/bin/touch -t 202401010101 "$screenshots/older.png"
/usr/bin/touch -t 202401010102 "$screenshots/newer.jpg"
/usr/bin/touch -t 202401010103 "$screenshots/nested/latest.gif"
/usr/bin/touch -t 202401010104 "$screenshots/nested/deeper/too-deep.png"
/usr/bin/touch -t 202401010105 "$override/override.png"

printf '' >"$workspace/commands.log"
set -l listed (run_function "$fake_bin" ss 2 | string collect)
assert_contains "$listed" "Últimos 2 screenshots en: $screenshots" 'ss default directory'
assert_contains "$listed" latest.gif 'ss includes nested image'
assert_contains "$listed" newer.jpg 'ss orders recent image'
assert_contains "$listed" 'justo ahora' 'ss formats recent file age'
string match -q '*older.png*' "$listed"; and fail 'ss honors count'
string match -q '*too-deep.png*' "$listed"; and fail 'ss ignores files deeper than two levels'
assert_contains (string collect <"$workspace/commands.log") "stat|-f|%m|$screenshots/nested/latest.gif" 'ss uses BSD stat arguments'

set -gx W4B_SCREENSHOTS_DIR "$override"
set listed (run_function "$fake_bin" ss 1 | string collect)
assert_contains "$listed" "Últimos 1 screenshots en: $override" 'ss override directory'
assert_contains "$listed" override.png 'ss override image'
set -e W4B_SCREENSHOTS_DIR

printf '' >"$workspace/commands.log"
set -l latest (run_function "$fake_bin" last)
assert_equal "$latest" "$screenshots/nested/latest.gif" 'last returns latest image path'

printf '' >"$workspace/commands.log"
run_function "$fake_bin" last --copy ignored >/dev/null
set -l commands (string collect <"$workspace/commands.log")
assert_contains "$commands" "pbcopy|$screenshots/nested/latest.gif" 'last forwards selected path to pbcopy'
string match -q '*open|*' "$commands"; and fail 'last copy must not open'

printf '' >"$workspace/commands.log"
run_function "$fake_bin" last --open >/dev/null
set commands (string collect <"$workspace/commands.log")
assert_contains "$commands" "open|$screenshots/nested/latest.gif" 'last forwards selected path to open'
string match -q '*pbcopy|*' "$commands"; and fail 'last open must not copy'

set -gx W4B_SCREENSHOTS_DIR "$override"
printf '' >"$workspace/commands.log"
run_function "$fake_bin" ssd >/dev/null
set commands (string collect <"$workspace/commands.log")
assert_equal "$commands" "open|$override" 'ssd opens override directory'
set -e W4B_SCREENSHOTS_DIR

set -gx W4B_SCREENSHOTS_DIR "$workspace/missing"
set -l fallback (run_function "$fake_bin" last)
assert_equal "$fallback" "$screenshots/nested/latest.gif" 'invalid override falls back to default screenshots directory'
set -e W4B_SCREENSHOTS_DIR

set -gx W4B_HOME "$workspace/no-screen-home"
mkdir -p "$W4B_HOME"
if run_function "$fake_bin" ss >"$workspace/missing.out" 2>&1
    fail 'ss missing default directory must fail'
end
assert_contains (string collect <"$workspace/missing.out") "Directorio no encontrado: $W4B_HOME/Desktop" 'ss missing directory error'
if run_function "$fake_bin" last >"$workspace/last-missing.out" 2>&1
    fail 'last missing default directory must fail'
end
assert_contains (string collect <"$workspace/last-missing.out") "No se encontraron screenshots en: $W4B_HOME/Desktop" 'last missing directory error'
set -l ssd_missing (run_function "$fake_bin" ssd)
assert_contains "$ssd_missing" "Directorio no encontrado: $W4B_HOME/Desktop" 'ssd missing directory error'
mkdir -p "$W4B_HOME/Desktop"
if run_function "$fake_bin" last >"$workspace/last-empty.out" 2>&1
    fail 'last empty directory must fail'
end
assert_contains (string collect <"$workspace/last-empty.out") "No se encontraron screenshots en: $W4B_HOME/Desktop" 'last empty directory error'
set -e W4B_HOME

set -l resolved_image (path resolve "$screenshots/newer.jpg")
printf '' >"$workspace/commands.log"
run_function "$fake_bin" imgclip "$screenshots/newer.jpg" >/dev/null
set commands (string collect <"$workspace/commands.log")
assert_contains "$commands" "osascript|-e|set the clipboard to (read (POSIX file \"$resolved_image\") as «class PNGf»)" 'imgclip forwards resolved image path'

printf '' >"$workspace/commands.log"
set -gx W4B_OSASCRIPT_FAIL_FIRST 1
run_function "$fake_bin" imgclip "$screenshots/newer.jpg" >/dev/null
set commands (string collect <"$workspace/commands.log")
set -l osascript_calls (string match -ra 'osascript\|' -- "$commands")
test (count $osascript_calls) -eq 2; or fail 'imgclip falls back after PNG clipboard attempt'
assert_contains "$commands" "set the clipboard to POSIX file \"$resolved_image\"" 'imgclip fallback arguments'
set -e W4B_OSASCRIPT_FAIL_FIRST

if run_function "$fake_bin" imgclip "$screenshots/ignored.txt" >"$workspace/unsupported.out" 2>&1
    fail 'imgclip unsupported format must fail'
end
assert_contains (string collect <"$workspace/unsupported.out") 'Formato no soportado: txt' 'imgclip unsupported format error'
if run_function "$fake_bin" imgclip "$workspace/missing.png" >"$workspace/missing-image.out" 2>&1
    fail 'imgclip missing file must fail'
end
assert_contains (string collect <"$workspace/missing-image.out") "Archivo no encontrado: $workspace/missing.png" 'imgclip missing file error'

set commands (string collect <"$workspace/commands.log")
string match -q '*screencapture|*' "$commands"; and fail 'helpers must not capture the screen'
string match -q '*pngpaste|*' "$commands"; and fail 'helpers must not read the clipboard'

printf 'PASS: Fish W4b screenshot helpers\n'
