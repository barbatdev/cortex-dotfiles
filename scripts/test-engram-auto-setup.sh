#!/bin/bash
# Evaluate only the Gentle channel exports from zsh/cortex-dotfiles.zsh in a
# clean zsh (no profile, no local env) and check defaults and overrides.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
profile="$repo_root/zsh/cortex-dotfiles.zsh"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

exports="$(grep -E '^export (GENTLE_AI_CHANNEL|GENTLE_SHELL_NO_AUTO_SETUP)=' "$profile")"
run() { env -i PATH="$PATH" "$@" zsh -f -c "$exports"$'\nprint -r -- "$GENTLE_AI_CHANNEL|${GENTLE_SHELL_NO_AUTO_SETUP-unset}"'; }

[ "$(run)" = "beta|1" ] || fail "defaults: got '$(run)', want 'beta|1'"
[ "$(run GENTLE_SHELL_NO_AUTO_SETUP=0)" = "beta|0" ] || fail "override 0 not kept: '$(run GENTLE_SHELL_NO_AUTO_SETUP=0)'"
[ "$(run GENTLE_AI_CHANNEL=stable)" = "stable|1" ] || fail "channel override: '$(run GENTLE_AI_CHANNEL=stable)'"
echo "PASS: engram auto-setup guard"
