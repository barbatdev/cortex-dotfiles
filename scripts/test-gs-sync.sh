#!/bin/bash
# Run the real `gs sync` (consumer mode) with an isolated HOME and PATH shims:
# no network, no host installs. Checks that the binaries step is followed by
# `gentle-ai sync`, scoped by GS_SYNC_AGENTS and skippable with GS_SKIP_AI_SYNC.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
ws="$(mktemp -d)"
trap 'rm -rf "$ws"' EXIT

fail() { printf 'FAIL: %s\n%s\n' "$1" "${2:-}" >&2; exit 1; }

home="$ws/home"
shims="$ws/shims"
log="$ws/calls.log"
mkdir -p "$home/.pi/gentle-ai" "$shims"

# One shim script, dispatched by name; every call is logged.
cat >"$shims/_shim" <<EOF
#!/bin/bash
name=\$(basename "\$0")
printf '%s|%s\n' "\$name" "\$*" >>"$log"
case "\$name \$1" in
  "gentle-shell --version") echo "gentle-shell 4.2.0-main.abc1234def56" ;;
  node\ *) echo "gentle-shell 4.2.0-main.abc1234def56" ;;
  "go install")
    for arg in "\$@"; do case "\$arg" in *cmd/engram@*)
      printf '#!/bin/sh\necho "engram 3.0.0"\n' >"\$GOBIN/engram"; chmod +x "\$GOBIN/engram" ;;
    esac; done ;;
  "gentle-ai --version") echo "gentle-ai 4.2.1" ;;
  "gentle-ai sync") [ -n "\${FAKE_AI_SYNC_FAIL:-}" ] && { echo "Error: partial sync"; exit 1; }; echo "managed sync executed"; [ -n "\${FAKE_AI_SYNC_CHANGED:-}" ] && echo "Sync actions executed: \$FAKE_AI_SYNC_CHANGED files changed"; true ;;
esac
exit 0
EOF
chmod +x "$shims/_shim"
for name in gentle-shell pi go home-manager node; do ln -s _shim "$shims/$name"; done
ai_dir="$ws/ai"; mkdir -p "$ai_dir"; ln -s "$shims/_shim" "$ai_dir/gentle-ai"
printf '{"schema":"gentle-pi.dev-binary/v1","path":"%s"}\n' "$ai_dir/gentle-ai" >"$home/.pi/gentle-ai/dev-binary.json"

run_sync() {
  : >"$log"
  env -i HOME="$home" PATH="$shims:/usr/bin:/bin" TERM=dumb GS_SHELL_REMOTE="$ws/no-remote" "$@" \
    bash "$repo_root/bin/gs" sync 2>&1
}
ai_sync_calls() { grep '^gentle-ai|sync' "$log" || true; }

# 1. Default: gentle-ai sync runs once, unscoped, after the binaries step.
out=$(run_sync) || fail 'gs sync exited non-zero' "$out"
[[ "$(ai_sync_calls)" == 'gentle-ai|sync' ]] || fail 'expected one unscoped gentle-ai sync' "$(cat "$log")"
[[ "$out" == *'gentle-ai sync'*'ok'* ]] || fail 'missing gentle-ai sync status line' "$out"
engram_line=$(grep -n 'cmd/engram@main' "$log" | cut -d: -f1)
sync_line=$(grep -n '^gentle-ai|sync' "$log" | cut -d: -f1)
(( engram_line < sync_line )) || fail 'gentle-ai sync ran before the binaries step' "$(cat "$log")"

[[ "$out" == *'nothing changed'* ]] || fail 'no-op sync should not ask for a Pi restart' "$out"

# 1b. Config changes from gentle-ai sync also ask for a Pi restart.
out=$(run_sync FAKE_AI_SYNC_CHANGED=3) || fail 'gs sync exited non-zero' "$out"
[[ "$out" == *'changed: managed configs (3 files)'*'Restart Pi'* ]] || fail 'config changes not reported' "$out"

# 2. GS_SYNC_AGENTS scopes the runtimes for this host.
out=$(run_sync GS_SYNC_AGENTS=claude-code,opencode,pi) || fail 'scoped gs sync exited non-zero' "$out"
[[ "$(ai_sync_calls)" == 'gentle-ai|sync --agents claude-code,opencode,pi' ]] || fail 'agents scope not forwarded' "$(cat "$log")"

# 3. GS_SKIP_AI_SYNC=1 keeps the binaries-only behavior.
out=$(run_sync GS_SKIP_AI_SYNC=1) || fail 'skipped gs sync exited non-zero' "$out"
[[ -z "$(ai_sync_calls)" ]] || fail 'gentle-ai sync ran despite GS_SKIP_AI_SYNC=1' "$(cat "$log")"
[[ "$out" == *'gentle-ai sync'*'skipped (GS_SKIP_AI_SYNC=1)'* ]] || fail 'missing skip status line' "$out"

# 4. A failing gentle-ai sync is reported with its output, gs sync goes on to the
#    closing report, and then exits 1 with INCOMPLETE instead of claiming success.
out=$(run_sync FAKE_AI_SYNC_FAIL=1) && fail 'gs sync exited 0 despite a failed gentle-ai sync' "$out"
[[ "$out" == *'INCOMPLETE — failed: gentle-ai sync'* ]] || fail 'failed step not in INCOMPLETE summary' "$out"
[[ "$out" != *'no Pi restart needed'* ]] || fail 'claimed no restart needed after a failure' "$out"
[[ "$out" == *'gentle-ai sync'*'FAILED'*'Error: partial sync'* ]] || fail 'failure output not surfaced' "$out"
[[ "$out" == *'versions:'* ]] || fail 'sync stopped before the closing report' "$out"

# 5. Legacy upgrade scripts are flagged so only gs sync remains.
mkdir -p "$home/.local/bin"; printf '#!/bin/sh\n' >"$home/.local/bin/gentle-maintainer-upgrade"
out=$(run_sync) || fail 'gs sync exited non-zero with legacy script' "$out"
[[ "$out" == *"WARN: legacy upgrade script $home/.local/bin/gentle-maintainer-upgrade"* ]] || fail 'legacy script not flagged' "$out"
[[ -f "$home/.local/bin/gentle-maintainer-upgrade" ]] || fail 'legacy script was removed' "$out"

# 6. Dotfiles step. A real local clone with a bare origin, so pull works offline.
dot="$home/dev/barbatdev/cortex/cortex-dotfiles"
origin="$ws/origin.git"
target="$home/.config/fish/conf.d/10-core.fish"
g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@"; }
g init -q --bare "$origin"
g clone -q "$origin" "$dot" 2>/dev/null
mkdir -p "$dot/fish/conf.d" && echo 'core v1' >"$dot/fish/conf.d/10-core.fish"
g -C "$dot" add -A && g -C "$dot" commit -qm v1 && g -C "$dot" push -q origin HEAD:main
dot_status() { grep -E '^  (dotfiles|10-core.fish) ' <<<"$1" || true; }

# 6a. GS_SKIP_DOTFILES=1 skips everything.
out=$(run_sync GS_SKIP_DOTFILES=1) || fail 'gs sync failed with GS_SKIP_DOTFILES' "$out"
[[ "$(dot_status "$out")" == *'skipped (GS_SKIP_DOTFILES=1)'* ]] || fail 'dotfiles skip line missing' "$out"
[[ ! -e "$target" && ! -L "$target" ]] || fail '10-core.fish installed despite skip' "$out"

# 6b. No clone: skip and keep going.
out=$(run_sync CORTEX_DOTFILES_DIR="$ws/nowhere") || fail 'gs sync failed without clone' "$out"
[[ "$(dot_status "$out")" == *"skipped (no clone at $ws/nowhere)"* ]] || fail 'no-clone skip missing' "$out"
[[ "$out" == *'versions:'* ]] || fail 'sync stopped after missing clone' "$out"

# 6c. Upstream moves; the clean clone on main is pulled and the hint names it.
up="$ws/upstream"; g clone -q "$origin" "$up"
echo 'core v2' >"$up/fish/conf.d/10-core.fish"; g -C "$up" commit -qam v2 && g -C "$up" push -q origin HEAD:main
old=$(git -C "$dot" rev-parse --short HEAD); new=$(git -C "$up" rev-parse --short HEAD)
mkdir -p "$(dirname "$target")"; echo 'host copy' >"$target"
out=$(run_sync) || fail 'gs sync failed on dotfiles pull' "$out"
[[ "$(git -C "$dot" rev-parse --short HEAD)" == "$new" ]] || fail 'clone was not pulled' "$out"
[[ "$out" == *"dotfiles ($old -> $new)"* ]] || fail 'restart hint misses dotfiles change' "$out"
# 6d. A regular host copy is backed up byte-for-byte and replaced by a link to the clone.
[[ "$(<"$target.pre-gs")" == 'host copy' ]] || fail 'host copy not backed up' "$(ls -la "$(dirname "$target")")"
[[ -L "$target" && "$(readlink "$target")" == "$dot/fish/conf.d/10-core.fish" ]] || fail '10-core.fish not linked to the clone' "$(ls -la "$target")"
[[ "$(dot_status "$out")" == *'10-core.fish'*'linked'* ]] || fail 'link status line missing' "$out"
# 6e. Second run: nothing to pull, link already right.
out=$(run_sync) || fail 'second gs sync failed' "$out"
[[ "$(dot_status "$out")" == *'10-core.fish'*'ok'* ]] || fail 'second run should be a no-op' "$out"
[[ "$out" != *'dotfiles ('* ]] || fail 'no-op pull reported as change' "$out"

# 6f. Local changes or another branch: clone untouched.
echo dirty >>"$dot/fish/conf.d/10-core.fish"
head=$(git -C "$dot" rev-parse HEAD)
out=$(run_sync) || fail 'gs sync failed with dirty clone' "$out"
[[ "$(dot_status "$out")" == *"skipped ($dot has local changes)"* ]] || fail 'dirty skip missing' "$out"
[[ "$(tail -1 "$dot/fish/conf.d/10-core.fish")" == dirty && "$(git -C "$dot" rev-parse HEAD)" == "$head" ]] || fail 'dirty clone was touched' "$out"
git -C "$dot" checkout -q -- . && git -C "$dot" checkout -q -b topic
out=$(run_sync) || fail 'gs sync failed on topic branch' "$out"
[[ "$(dot_status "$out")" == *"skipped ($dot is on topic, not main)"* ]] || fail 'branch skip missing' "$out"
git -C "$dot" checkout -q main

# 6g. Home Manager owns 10-core.fish: switch through the flake, never relink.
store="$ws/nix/store"; mkdir -p "$store/hm/fish"; echo hm >"$store/hm/fish/10-core.fish"
rm -f "$target"; ln -s "$store/hm/fish/10-core.fish" "$target"
out=$(run_sync GS_HM_STORE_PREFIX="$store") || fail 'gs sync failed with Home Manager' "$out"
grep -q "^home-manager|switch --flake $dot#jbarbat" "$log" || fail 'home-manager switch not called with the flake' "$(cat "$log")"
grep -q "^home-manager|.* -b pre-gs" "$log" || fail 'home-manager switch without backup suffix' "$(cat "$log")"
[[ "$(readlink "$target")" == "$store/hm/fish/10-core.fish" ]] || fail 'Home Manager link was replaced' "$(ls -la "$target")"
out=$(run_sync GS_HM_STORE_PREFIX="$store" GS_HM_CONFIG=custom) || fail 'gs sync failed with GS_HM_CONFIG' "$out"
grep -q "^home-manager|switch --flake $dot#custom -b pre-gs" "$log" || fail 'GS_HM_CONFIG ignored' "$(cat "$log")"

echo "gs sync checks passed"
