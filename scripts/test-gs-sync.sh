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
  "gentle-shell --version") echo "gentle-shell 4.2.0" ;;
  "go install")
    for arg in "\$@"; do case "\$arg" in *cmd/engram@*)
      printf '#!/bin/sh\necho "engram 3.0.0"\n' >"\$GOBIN/engram"; chmod +x "\$GOBIN/engram" ;;
    esac; done ;;
  "gentle-ai --version") echo "gentle-ai 4.2.1" ;;
  "gentle-ai sync") [ -n "\${FAKE_AI_SYNC_FAIL:-}" ] && { echo "Error: partial sync"; exit 1; }; echo "managed sync executed" ;;
esac
exit 0
EOF
chmod +x "$shims/_shim"
for name in gentle-shell pi go; do ln -s _shim "$shims/$name"; done
ai_dir="$ws/ai"; mkdir -p "$ai_dir"; ln -s "$shims/_shim" "$ai_dir/gentle-ai"
printf '{"schema":"gentle-pi.dev-binary/v1","path":"%s"}\n' "$ai_dir/gentle-ai" >"$home/.pi/gentle-ai/dev-binary.json"

run_sync() {
  : >"$log"
  env -i HOME="$home" PATH="$shims:/usr/bin:/bin" TERM=dumb "$@" \
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

# 2. GS_SYNC_AGENTS scopes the runtimes for this host.
out=$(run_sync GS_SYNC_AGENTS=claude-code,opencode,pi) || fail 'scoped gs sync exited non-zero' "$out"
[[ "$(ai_sync_calls)" == 'gentle-ai|sync --agents claude-code,opencode,pi' ]] || fail 'agents scope not forwarded' "$(cat "$log")"

# 3. GS_SKIP_AI_SYNC=1 keeps the binaries-only behavior.
out=$(run_sync GS_SKIP_AI_SYNC=1) || fail 'skipped gs sync exited non-zero' "$out"
[[ -z "$(ai_sync_calls)" ]] || fail 'gentle-ai sync ran despite GS_SKIP_AI_SYNC=1' "$(cat "$log")"
[[ "$out" == *'gentle-ai sync'*'skipped (GS_SKIP_AI_SYNC=1)'* ]] || fail 'missing skip status line' "$out"

# 4. A failing gentle-ai sync is reported with its output, and gs sync goes on.
out=$(run_sync FAKE_AI_SYNC_FAIL=1) || fail 'gs sync aborted on gentle-ai sync failure' "$out"
[[ "$out" == *'gentle-ai sync'*'FAILED'*'Error: partial sync'* ]] || fail 'failure output not surfaced' "$out"
[[ "$out" == *'versions:'* ]] || fail 'sync stopped before the closing report' "$out"

# 5. Legacy upgrade scripts are flagged so only gs sync remains.
mkdir -p "$home/.local/bin"; printf '#!/bin/sh\n' >"$home/.local/bin/gentle-maintainer-upgrade"
out=$(run_sync) || fail 'gs sync exited non-zero with legacy script' "$out"
[[ "$out" == *"WARN: legacy upgrade script $home/.local/bin/gentle-maintainer-upgrade"* ]] || fail 'legacy script not flagged' "$out"
[[ -f "$home/.local/bin/gentle-maintainer-upgrade" ]] || fail 'legacy script was removed' "$out"

echo "gs sync checks passed"
