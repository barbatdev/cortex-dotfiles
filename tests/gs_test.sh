#!/usr/bin/env bash
# Regression tests for bin/gs: launch target and sync result share one source of truth.
# Runs fully offline in a throwaway HOME with stub binaries. Usage: tests/gs_test.sh
set -uo pipefail

GS="${GS_BIN:-$(cd "$(dirname "$0")/.." && pwd)/bin/gs}"
REAL_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
fails=0

ok()   { printf 'ok   %s\n' "$1"; }
bad()  { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; printf '%s\n' "$OUT" | sed 's/^/     | /'; fi; }

# Fake package: bin/gentle-shell.mjs prints its version and records argv.
make_pkg() { # dir version
  mkdir -p "$1/bin"
  printf '#!/bin/sh\nexit 0\n' > "$1/bin/gentle-shell.mjs"
  printf '%s\n' "$2" > "$1/VERSION"
}

setup() { # mode: consumer | workshop
  T=$(cd "$(mktemp -d)" && pwd -P); export HOME="$T/home"; S="$T/stubs"; mkdir -p "$HOME/.local/bin" "$S"
  export PATH="$S:$HOME/.local/bin:$REAL_PATH" GS_SKIP_DOTFILES=1 GS_SKIP_AI_SYNC=1
  export GS_SHELL_REMOTE="$T/remote" CALLS="$T/calls"
  # node stub: "node <pkg>/bin/gentle-shell.mjs ARGS" -> version or argv log.
  cat > "$S/node" <<'EOF'
#!/bin/sh
pkg=$(dirname "$(dirname "$1")"); shift
if [ "${1:-}" = --version ]; then printf 'gentle-shell %s\npi 1.4.0\n' "$(cat "$pkg/VERSION")"; exit 0; fi
echo "launch $pkg $*" >> "$CALLS"
[ "${2:-}" = setup ] && exit "${SETUP_RC:-0}"
exit 0
EOF
  printf '#!/bin/sh\necho "go PATH=$PATH" >> "$CALLS"\n' > "$S/go"
  for b in pnpm npm; do printf '#!/bin/sh\nexit 0\n' > "$S/$b"; done
  printf '#!/bin/sh\necho "pi $*" >> "$CALLS"\necho "PATH=$PATH" >> "$CALLS"\n' > "$S/pi"
  # Legacy pi-managed checkout that must never be launched again.
  make_pkg "$HOME/.pi/agent/git/github.com/Gentleman-Programming/gentle-pi" 4.3.0
  # gentle-ai binary registered by the main channel.
  mkdir -p "$HOME/.pi/gentle-ai" "$HOME/.local/share/gentle-ai/main"
  printf '#!/bin/sh\n[ "$1" = --version ] && echo "gentle-ai 1.0.0"\nexit 0\n' > "$HOME/ai"
  chmod +x "$HOME/ai"
  printf '{"path":"%s"}\n' "$HOME/ai" > "$HOME/.pi/gentle-ai/dev-binary.json"
  if [ "$1" = consumer ]; then
    NPM="$HOME/.local/lib/node_modules/gentle-pi"
    make_pkg "$NPM" 4.5.1-main.feee99d88dae
    ln -s ../lib/node_modules/gentle-pi/bin/gentle-shell.mjs "$HOME/.local/bin/gentle-shell"
    # PATH gentle-shell stub: version from the package; upgrade bumps it.
    cat > "$S/gentle-shell-impl" <<EOF
#!/bin/sh
case "\$1" in
  --version) printf 'gentle-shell %s\n' "\$(cat "$NPM/VERSION")" ;;
  upgrade) [ -n "\${UPGRADE_TO:-}" ] && echo "\$UPGRADE_TO" > "$NPM/VERSION"; exit "\${UPGRADE_RC:-0}" ;;
esac
EOF
    chmod +x "$S/gentle-shell-impl"
    # The PATH entry is the symlink into the npm package; make it executable via the stub.
    printf '#!/bin/sh\nexec %s "$@"\n' "$S/gentle-shell-impl" > "$NPM/bin/gentle-shell.mjs"
  else
    mkdir -p "$HOME/dev/gentle"
    for r in gentle-shell gentle-ai engram; do
      git init -q "$HOME/dev/gentle/$r"
      git -C "$HOME/dev/gentle/$r" remote add origin "https://github.com/Gentleman-Programming/$r"
    done
    make_pkg "$HOME/dev/gentle/gentle-shell" 4.6.0
  fi
  chmod +x "$S"/* 2>/dev/null; find "$T" -name gentle-shell.mjs -exec chmod +x {} +
}

remote_main() { # sha: fake `git ls-remote` source for the freshness check
  git init -q "$GS_SHELL_REMOTE" 2>/dev/null
  git -C "$GS_SHELL_REMOTE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m x
  git -C "$GS_SHELL_REMOTE" update-ref refs/heads/main "$1"
}
sha_of() { git -C "$GS_SHELL_REMOTE" rev-parse HEAD; }

# --- launcher -----------------------------------------------------------------

setup consumer
OUT=$("$GS" --foo 2>&1); L=$(cat "$CALLS" 2>/dev/null)
check "consumer: gs launches the package behind gentle-shell on PATH, isolated" \
  '[[ "$L" == "launch $NPM --isolated --foo" ]]'
check "consumer: gs never launches the legacy pi git checkout" '[[ "$L" != *".pi/agent/git"* ]]'

setup consumer; rm "$HOME/.local/bin/gentle-shell"
OUT=$("$GS" 2>&1); rc=$?
check "consumer: no gentle-shell on PATH fails instead of opening the legacy copy" \
  '[ $rc -ne 0 ] && [[ "$OUT" == *"not on PATH"* ]] && [ ! -e "$CALLS" ]'

setup workshop
OUT=$("$GS" x 2>&1); L=$(cat "$CALLS" 2>/dev/null)
check "workshop: gs launches the clean clone, isolated" '[[ "$L" == "launch $HOME/dev/gentle/gentle-shell --isolated x" ]]'

# A gentle-shell worktree the operator is working in (dogfooding target).
make_worktree() {
  W="$HOME/dev/worktrees/gentle-shell-wip"; make_pkg "$W" 9.9.9-wip
  git init -q "$W"; mkdir -p "$W/node_modules"
  printf '{\n  "name": "gentle-pi"\n}\n' > "$W/package.json"
}

setup workshop; make_worktree
OUT=$(cd "$W/bin" && "$GS" y 2>&1); L=$(cat "$CALLS" 2>/dev/null)
check "workshop: inside a gentle-shell worktree gs loads that path" \
  '[[ "$L" == "launch $W --isolated --package-root $W y" ]]'

setup consumer; make_worktree
OUT=$(cd "$W" && "$GS" 2>&1); L=$(cat "$CALLS" 2>/dev/null)
check "consumer: inside a gentle-shell checkout gs still opens the main build" \
  '[[ "$L" == "launch $NPM --isolated" ]]'

setup workshop; make_worktree
OUT=$(cd "$W" && "$GS" run --z 2>&1); L=$(cat "$CALLS" 2>/dev/null)
check "workshop: gs run uses the isolated home with this worktree as --package-root" \
  '[[ "$L" == "launch $W --isolated --package-root $W --z" ]]'

# gs pr / gs issue on an existing shell worktree: Pi opens on it with the kickoff.
gh_stub() {
  cat > "$S/gh" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "issue view") printf 'OPEN\037\037fix: thing\037type:bug\n' ;;
esac
exit 0
EOF
  chmod +x "$S/gh"
}
setup workshop; gh_stub
W="$HOME/dev/worktrees/gentle-shell-pr-7"; make_pkg "$W" 9.9.9-pr
git init -q "$W"; mkdir -p "$W/node_modules"; printf '{\n  "name": "gentle-pi"\n}\n' > "$W/package.json"
git -C "$W" add -A; git -C "$W" -c user.email=t@t -c user.name=t commit -q -m pr
OUT=$("$GS" pr shell 7 2>&1); L=$(cat "$CALLS" 2>/dev/null)
check "workshop: gs pr opens the worktree isolated, never --link" \
  '[[ "$L" == "launch $W --isolated --package-root $W Review Gentleman-Programming/gentle-shell PR #7 "* ]] && [[ "$L" != *--link* ]]'
check "workshop: gs pr kickoff names the cortex skill without a legacy home path" \
  '[[ "$L" == *"cortex-maintainer-delivery skill"* ]] && [[ "$L" != *".pi/agent"* ]]'

setup workshop; gh_stub
W="$HOME/dev/worktrees/gentle-shell-issue-8"; make_pkg "$W" 9.9.9-is
git init -q "$W"; mkdir -p "$W/node_modules"; printf '{\n  "name": "gentle-pi"\n}\n' > "$W/package.json"
git -C "$W" add -A; git -C "$W" -c user.email=t@t -c user.name=t commit -q -m is
OUT=$("$GS" issue shell 8 2>&1); L=$(cat "$CALLS" 2>/dev/null)
check "workshop: gs issue reuses the worktree and opens it isolated, never --link" \
  '[[ "$OUT" == *"reusing $W"* ]] && [[ "$L" == "launch $W --isolated --package-root $W Take Gentleman-Programming/gentle-shell issue #8 "* ]] && [[ "$L" != *--link* ]]'
check "workshop: gs issue kickoff names the cortex skill without a legacy home path" \
  '[[ "$L" == *"cortex-maintainer-delivery skill"* ]] && [[ "$L" != *".pi/agent"* ]]'

# gs issue race check: only someone else's assignment blocks a new worktree.
race_stub() {
  cat > "$S/gh" <<EOF
#!/bin/sh
case "\$1 \$2" in
  "issue view") printf 'OPEN\037$1\037fix: thing\037type:bug\n' ;;
  "api user") echo me ;;
  "pr list") echo "pr list" >> "$CALLS" ;;
esac
exit 0
EOF
  chmod +x "$S/gh"
}
setup workshop; race_stub me
OUT=$("$GS" issue shell 9 2>&1); L=$(cat "$CALLS" 2>/dev/null)
check "workshop: gs issue assigned only to you passes the race check" \
  '[[ "$OUT" != *"is assigned"* ]] && [[ "$L" == *"pr list"* ]]'
setup workshop; race_stub other
OUT=$("$GS" issue shell 9 2>&1); rc=$?
check "workshop: gs issue assigned to someone else still stops" \
  '[ "$rc" = 1 ] && [[ "$OUT" == *"#9 is assigned to other (GS_FORCE=1 to continue)"* ]]'
setup workshop; race_stub me,other
OUT=$("$GS" issue shell 9 2>&1); rc=$?
check "workshop: gs issue shared with someone else stops and names only them" \
  '[ "$rc" = 1 ] && [[ "$OUT" == *"#9 is assigned to other (GS_FORCE=1 to continue)"* ]]'

# --- sync (workshop) ----------------------------------------------------------

setup workshop
# Clones need an origin with main; the path keeps the Gentleman-Programming name.
O="$T/Gentleman-Programming"; mkdir -p "$O"
for r in gentle-shell gentle-ai engram; do
  c="$HOME/dev/gentle/$r"
  git -C "$c" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$c" branch -M main
  git clone -q --bare "$c" "$O/$r.git"; git -C "$c" remote set-url origin "$O/$r.git"
  git -C "$c" fetch -q origin
done
git -C "$HOME/dev/gentle/gentle-shell" checkout -q --detach
mkdir -p "$HOME/dev/gentle/engram/plugin/pi"
rm "$S/pi"  # workshop needs no Pi runtime of its own on PATH
mkdir -p "$HOME/dev/gentle/gentle-shell/.engram" "$HOME/dev/gentle/gentle-shell/odd/checks"
touch "$HOME/dev/gentle/gentle-shell/.engram/x" "$HOME/dev/gentle/gentle-shell/odd/checks/y"
OUT=$("$GS" sync 2>&1); rc=$?
check "workshop sync: untracked session files and detached HEAD do not block it" \
  '[[ "$OUT" != *"clean clones only"* ]] && [ "$(git -C "$HOME/dev/gentle/gentle-shell" branch --show-current)" = main ] && [ -e "$HOME/dev/gentle/gentle-shell/.engram/x" ]'
REG="$HOME/.pi/gentle-ai/dev-binary.json"
check "workshop sync: registers gentle-ai main where the launcher reads it (~/.pi/gentle-ai, file 0600)" \
  '[ "$(cat "$REG")" = "{\"schema\":\"gentle-pi.dev-binary/v1\",\"path\":\"$HOME/.local/share/gentle-ai/main/gentle-ai\"}" ] && [ "$(stat -c %a "$REG" 2>/dev/null || stat -f %Lp "$REG")" = 600 ]'
check "workshop sync: writes no registration into the isolated config home" \
  '[ ! -e "$HOME/.gentle-shell/gentle-ai/dev-binary.json" ]'
check "workshop sync: never runs pi update nor adds ~/.pi/agent/bin to PATH" \
  '! grep -q "^pi " "$CALLS" 2>/dev/null && grep -q "^go PATH=" "$CALLS" && ! grep -q "PATH=.*\.pi/agent/bin" "$CALLS"'
mkdir -p "$HOME/.gentle-shell/agent"; printf '{"packages":["npm:gentle-pi","npm:gentle-engram"]}\n' > "$HOME/.gentle-shell/agent/settings.json"
OUT=$("$GS" sync 2>&1)
check "workshop sync: isolated home packages the official Shell requires raise no warning" \
  '[[ "$OUT" != *"WARN:"*"settings.json"* ]]'
# S8: workshop gentle-ai sync is Claude Code only, then the isolated home is provisioned.
AI="$HOME/.local/share/gentle-ai/main/gentle-ai"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "gentle-ai 1.0.0"; exit 0; }\necho "gentle-ai $*" >> "$CALLS"\n' > "$AI"; chmod +x "$AI"
SHELL_CLONE="$HOME/dev/gentle/gentle-shell"
: > "$CALLS"; OUT=$(env -u GS_SKIP_AI_SYNC "$GS" sync 2>&1); rc=$?
check "workshop sync: gentle-ai sync targets claude-code only, then gentle-shell setup on the isolated home" \
  '[ $rc -eq 0 ] && [ "$(grep -E "^gentle-ai sync|--isolated setup" "$CALLS")" = "$(printf "gentle-ai sync --agents claude-code\nlaunch %s --isolated setup" "$SHELL_CLONE")" ] && [[ "$OUT" == *"gentle-shell setup (isolated home)"*ok* ]]'
: > "$CALLS"; OUT=$(env -u GS_SKIP_AI_SYNC GS_SYNC_AGENTS=x "$GS" sync 2>&1)
check "workshop sync: GS_SYNC_AGENTS overrides the claude-code default" \
  'grep -qx "gentle-ai sync --agents x" "$CALLS"'
: > "$CALLS"; OUT=$(GS_SKIP_AI_SYNC=1 "$GS" sync 2>&1)
check "workshop sync: GS_SKIP_AI_SYNC=1 skips gentle-ai sync and gentle-shell setup" \
  '! grep -qE "^gentle-ai sync|--isolated setup" "$CALLS" && [[ "$OUT" == *"gentle-ai sync"*"skipped (GS_SKIP_AI_SYNC=1)"* ]] && [[ "$OUT" == *"gentle-shell setup (isolated home)"*"skipped (GS_SKIP_AI_SYNC=1)"* ]]'
OUT=$(env -u GS_SKIP_AI_SYNC SETUP_RC=1 "$GS" sync 2>&1); rc=$?
check "workshop sync: failed gentle-shell setup is INCOMPLETE, exit 1" \
  '[ $rc -eq 1 ] && [[ "$OUT" == *"INCOMPLETE"*"gentle-shell setup (isolated home)"* ]]'
rm "$HOME/.gentle-shell/agent/settings.json"
echo tracked >> "$HOME/dev/gentle/gentle-shell/VERSION"; git -C "$HOME/dev/gentle/gentle-shell" add VERSION
OUT=$("$GS" sync 2>&1); rc=$?
check "workshop sync: tracked edits in a clone still stop it" '[ $rc -ne 0 ] && [[ "$OUT" == *"clean clones only"* ]]'

# --- sync (consumer) ----------------------------------------------------------

setup consumer; remote_main HEAD; main=$(sha_of)
OUT=$(UPGRADE_TO="4.5.2-main.${main:0:12}" "$GS" sync 2>&1); rc=$?
check "sync: reports the version gs opens, from the same package" \
  '[ $rc -eq 0 ] && [[ "$OUT" == *"gs opens:  4.5.2-main.${main:0:12} ($NPM)"* ]]'
check "sync: a real update asks for a restart" '[[ "$OUT" == *"shell (4.5.1-main.feee99d88dae -> 4.5.2-main"* ]]'
check "consumer sync: still runs pi update and pi update --extensions" \
  'grep -qx "pi update" "$CALLS" && grep -qx "pi update --extensions" "$CALLS"'
check "sync: warns about the unused legacy checkout without deleting it" \
  '[[ "$OUT" == *"stale legacy checkout"* ]] && [ -d "$HOME/.pi/agent/git/github.com/Gentleman-Programming/gentle-pi" ]'

setup consumer; remote_main HEAD
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "gentle-ai 1.0.0"; exit 0; }\necho "gentle-ai $*" >> "$CALLS"\n' > "$HOME/ai"
OUT=$(env -u GS_SKIP_AI_SYNC "$GS" sync 2>&1)
check "consumer sync: still runs bare gentle-ai sync (no --agents) and no gentle-shell setup" \
  'grep -qx "gentle-ai sync" "$CALLS" && ! grep -q -- "--isolated setup" "$CALLS" && [[ "$OUT" != *"gentle-shell setup"* ]]'

setup consumer; remote_main HEAD; main=$(sha_of)
echo "4.5.2-main.${main:0:12}" > "$NPM/VERSION"
OUT=$("$GS" sync 2>&1); rc=$?
check "sync: current and unchanged says no restart needed" \
  '[ $rc -eq 0 ] && [[ "$OUT" == *"no Pi restart needed"* ]]'

setup consumer; remote_main HEAD
OUT=$(UPGRADE_RC=1 "$GS" sync 2>&1); rc=$?
check "sync: failed upgrade is INCOMPLETE, exit 1, never 'no restart needed'" \
  '[ $rc -eq 1 ] && [[ "$OUT" == *"INCOMPLETE"*"gentle-shell upgrade (main)"* ]] && [[ "$OUT" != *"no Pi restart needed"* ]]'

setup consumer; remote_main HEAD
OUT=$("$GS" sync 2>&1); rc=$?
check "sync: launch target behind GitHub main is INCOMPLETE" \
  '[ $rc -eq 1 ] && [[ "$OUT" == *"gentle-shell behind main (built feee99d88dae"* ]]'

setup consumer; rm -rf "$GS_SHELL_REMOTE"; export GS_SHELL_REMOTE="$T/missing"
OUT=$("$GS" sync 2>&1); rc=$?
check "sync: unreachable GitHub only warns that freshness is unverified" \
  '[ $rc -eq 0 ] && [[ "$OUT" == *"freshness unverified"* ]]'

printf '\n%s\n' "$([ $fails -eq 0 ] && echo 'all passed' || echo "$fails failed")"
exit $fails
