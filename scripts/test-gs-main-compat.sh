#!/usr/bin/env bash
# In-memory sandbox: fake HOME, Git, filesystem checks and Node; no installs or settings writes.
set -euo pipefail

GS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/gs"
# GS_BASELINE=1 reads the original tracked launcher through a pipe, never altering the checkout.
GS_BASELINE=${GS_BASELINE:-0}
ROOT='/sandbox/worktree with spaces'
CONSUMER='/sandbox/home/.pi/agent/git/github.com/Gentleman-Programming/gentle-pi'
WORKSHOP='/sandbox/home/dev/gentle/gentle-shell'

fail() { printf 'FAIL: %s\n%s\n' "$1" "${2:-}" >&2; exit 1; }

run_case() (
  HOME=/sandbox/home
  export HOME
  # These functions model a temporary, isolated filesystem and executable PATH.
  git() {
    if [[ "$1" == rev-parse && "$2" == --show-toplevel ]]; then printf '%s\n' "$ROOT"
    elif [[ "$1" == -C && "$3" == rev-parse ]]; then printf '4431a86f\n'
    elif [[ "$1" == -C && "$3" == remote ]]; then
      [[ "$SCENARIO" == workshop ]] || return 1
      printf 'git@github.com:Gentleman-Programming/gentle-shell.git\n'
    else return 1; fi
  }
  grep() {
    if [[ "${3:-}" == "$ROOT/package.json" ]]; then return 0; fi
    [[ "$SCENARIO" == workshop && "$*" == *Gentleman-Programming/gentle-shell* ]]
  }
  function [ {
    if [[ "$1" == '!' && "$2" == -f ]]; then
      if [ -f "$3" ]; then return 1; else return 0; fi
    fi
    if [[ "$1" == -d && "$2" == "$ROOT/node_modules" ]]; then
      [[ "$SCENARIO" != no-deps ]]
      return
    elif [[ "$1" == -f ]]; then
      case "$2" in
        "$ROOT/bin/gentle-shell.mjs") [[ "$SCENARIO" == local ]]; return ;;
        "$CONSUMER/bin/gentle-shell.mjs") [[ "$SCENARIO" == consumer || "$SCENARIO" == no-deps ]]; return ;;
        "$WORKSHOP/bin/gentle-shell.mjs") [[ "$SCENARIO" == workshop ]]; return ;;
      esac
    fi
    builtin test "${@:1:$#-1}"
  }
  cd() { printf 'CD %s\n' "$1"; }
  exec() {
    if [[ "$2" == "$ROOT/bin/gentle-shell.mjs" && "$SCENARIO" != local ]]; then
      printf 'Error: Cannot find module %s\n' "$2" >&2
      return 1
    fi
    printf 'ARGV %q\n' "$@"
  }
  SCENARIO=$1
  shift
  # Sourcing exercises the real case dispatch without writing to a fake HOME.
  set -- run "$@"
  if [[ "$GS_BASELINE" == 1 ]]; then
    source <(command git -C "${GS%/bin/gs}" show HEAD:bin/gs)
  else
    source "$GS"
  fi
)

args=('two words' '--flag=x y' 'literal*')
for scenario in local consumer workshop; do
  result=$(run_case "$scenario" "${args[@]}" 2>&1) || fail "$scenario exited nonzero" "$result"
  case "$scenario" in
    local) launcher="$ROOT/bin/gentle-shell.mjs" ;;
    consumer) launcher="$CONSUMER/bin/gentle-shell.mjs" ;;
    workshop) launcher="$WORKSHOP/bin/gentle-shell.mjs" ;;
  esac
  [[ "$result" == *"CD $ROOT"* ]] || fail "$scenario did not retain worktree cwd" "$result"
  expected=$(printf 'ARGV %q\n' node "$launcher" --link --package-root "$ROOT" "${args[@]}")
  [[ "$result" == *"$expected"* ]] || fail "$scenario launcher/root/args mismatch" "$result"
  if [[ "$scenario" != local ]]; then
    [[ "$result" == *"$launcher"* && "$result" == *"$ROOT"* && "$result" == *fallback* ]] ||
      fail "$scenario missing explicit fallback source and target notice" "$result"
  fi
done

result=$(run_case no-deps 'one arg' 2>&1) && fail 'fallback without PR dependencies succeeded' "$result"
[[ "$result" == *'gs: no node_modules'* && "$result" == *"$ROOT"* ]] ||
  fail 'fallback without PR dependencies needs a worktree dependency error' "$result"
[[ "$result" != *'fallback launcher'* && "$result" != *'ARGV '* ]] ||
  fail 'fallback without PR dependencies reached main launcher' "$result"

result=$(run_case missing 'one arg' 2>&1) && fail 'missing launchers succeeded' "$result"
[[ "$result" == *'gs:'* && "$result" == *'gs sync'* && "$result" == *'--package-root'* ]] ||
  fail 'missing launchers need actionable gs error with main update requirement' "$result"
[[ "$result" != *'Cannot find module'* ]] || fail 'raw Node missing-module leaked' "$result"

# Static sync assertion: no sync execution (which would install and edit settings).
command grep -Fq 'GOPROXY=direct GOBIN="$bin" go install github.com/gentleman-programming/gentle-ai/v4/cmd/gentle-ai@main' "$GS" ||
  fail 'consumer gentle-ai go install must target v4@main'
command grep -Fq 'GOPROXY=direct GOBIN="$bin" go install github.com/Gentleman-Programming/engram/v2/cmd/engram@main' "$GS" ||
  fail 'consumer engram go install must retain v2@main and GOPROXY'
printf 'PASS: gs local, consumer, workshop, no-deps, missing launchers, args/root, static sync targets\n'
