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
EOF
  for b in pi go pnpm npm; do printf '#!/bin/sh\nexit 0\n' > "$S/$b"; done
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
check "consumer: gs launches the package behind gentle-shell on PATH" \
  '[[ "$L" == "launch $NPM --link --foo" ]]'
check "consumer: gs never launches the legacy pi git checkout" '[[ "$L" != *".pi/agent/git"* ]]'

setup consumer; rm "$HOME/.local/bin/gentle-shell"
OUT=$("$GS" 2>&1); rc=$?
check "consumer: no gentle-shell on PATH fails instead of opening the legacy copy" \
  '[ $rc -ne 0 ] && [[ "$OUT" == *"not on PATH"* ]] && [ ! -e "$CALLS" ]'

setup workshop
OUT=$("$GS" x 2>&1); L=$(cat "$CALLS" 2>/dev/null)
check "workshop: gs launches the clean clone" '[[ "$L" == "launch $HOME/dev/gentle/gentle-shell --link x" ]]'

# A gentle-shell worktree the operator is working in (dogfooding target).
make_worktree() {
  W="$HOME/dev/worktrees/gentle-shell-wip"; make_pkg "$W" 9.9.9-wip
  git init -q "$W"; mkdir -p "$W/node_modules"
  printf '{\n  "name": "gentle-pi"\n}\n' > "$W/package.json"
}

setup workshop; make_worktree
OUT=$(cd "$W/bin" && "$GS" y 2>&1); L=$(cat "$CALLS" 2>/dev/null)
check "workshop: inside a gentle-shell worktree gs loads that path" \
  '[[ "$L" == "launch $W --link --package-root $W y" ]]'

setup consumer; make_worktree
OUT=$(cd "$W" && "$GS" 2>&1); L=$(cat "$CALLS" 2>/dev/null)
check "consumer: inside a gentle-shell checkout gs still opens the main build" \
  '[[ "$L" == "launch $NPM --link" ]]'

# --- sync (consumer) ----------------------------------------------------------

setup consumer; remote_main HEAD; main=$(sha_of)
OUT=$(UPGRADE_TO="4.5.2-main.${main:0:12}" "$GS" sync 2>&1); rc=$?
check "sync: reports the version gs opens, from the same package" \
  '[ $rc -eq 0 ] && [[ "$OUT" == *"gs opens:  4.5.2-main.${main:0:12} ($NPM)"* ]]'
check "sync: a real update asks for a restart" '[[ "$OUT" == *"shell (4.5.1-main.feee99d88dae -> 4.5.2-main"* ]]'
check "sync: warns about the unused legacy checkout without deleting it" \
  '[[ "$OUT" == *"stale legacy checkout"* ]] && [ -d "$HOME/.pi/agent/git/github.com/Gentleman-Programming/gentle-pi" ]'

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
