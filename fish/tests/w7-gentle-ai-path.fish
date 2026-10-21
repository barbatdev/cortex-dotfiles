#!/usr/bin/env fish
# gentle-ai's managed launcher dir (~/.gentle-ai/bin) must lead PATH when present,
# because gentle-ai cannot persist PATH for fish login shells itself.

set -l repo_root (cd (dirname (dirname (status filename))); and pwd)
set -l core "$repo_root/conf.d/10-core.fish"
set -l fish_bin (status fish-path)
set -l ws (mktemp -d)

function fail
    printf 'FAIL: %s\n' "$argv" >&2
    exit 1
end

set -l probe 'source $argv[1]; string join "|" $PATH'

mkdir -p "$ws/with/.gentle-ai/bin" "$ws/without"
set -l with (env -i HOME="$ws/with" PATH=/usr/bin:/bin "$fish_bin" --no-config -c "$probe" "$core")
string match -q "$ws/with/.gentle-ai/bin|*" -- "$with"; or fail "launcher dir not first in PATH: $with"

set -l twice (env -i HOME="$ws/with" PATH="$ws/with/.gentle-ai/bin:/usr/bin:/bin" "$fish_bin" --no-config -c "$probe" "$core")
test (count (string match -a -- "$ws/with/.gentle-ai/bin" (string split '|' -- "$twice"))) -eq 1; or fail "launcher dir duplicated: $twice"

set -l without (env -i HOME="$ws/without" PATH=/usr/bin:/bin "$fish_bin" --no-config -c "$probe" "$core")
string match -q '*gentle-ai*' -- "$without"; and fail "missing launcher dir added to PATH: $without"

# Every host follows the beta channel (gs sync installs from main); a host may override.
set -l channel (env -i HOME="$ws/without" PATH=/usr/bin:/bin "$fish_bin" --no-config -c 'source $argv[1]; echo $GENTLE_AI_CHANNEL' "$core")
test "$channel" = beta; or fail "GENTLE_AI_CHANNEL default (expected beta, got '$channel')"
set -l override (env -i HOME="$ws/without" PATH=/usr/bin:/bin GENTLE_AI_CHANNEL=stable "$fish_bin" --no-config -c 'source $argv[1]; echo $GENTLE_AI_CHANNEL' "$core")
test "$override" = stable; or fail "GENTLE_AI_CHANNEL override not kept (got '$override')"

rm -rf -- "$ws"
printf 'gentle-ai path checks passed\n'
