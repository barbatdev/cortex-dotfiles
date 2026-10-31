#!/usr/bin/env bash
# migrate-mac-official.sh — migrate this Mac from the legacy Gentle stack to the
# official Gentle Shell (main channel) + external Gentle AI for Claude Code.
#
# Usage:
#   bash scripts/migrate-mac-official.sh --backup DIR           # dry-run (default)
#   bash scripts/migrate-mac-official.sh --backup DIR --apply   # perform migration
#
# DIR must contain profiles.json and refactoria.json saved before the migration.
# Run it from a plain terminal with every gentle-shell session closed.
# Dry-run runs every preflight check, prints the full plan, and changes nothing
# (exit 0 even with blockers). --apply refuses if any blocker exists.
# Never touches auth, sessions, Engram, or LaunchAgents; never uses --link.

set -u

#region Arguments
BACKUP=""
APPLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --backup) BACKUP="${2:-}"; shift 2 || { echo "--backup needs DIR" >&2; exit 2; } ;;
    --apply) APPLY=1; shift ;;
    -h|--help) sed -n '2,13s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$BACKUP" ] || { echo "usage: $0 --backup DIR [--apply]" >&2; exit 2; }

DOT="${CORTEX_DOTFILES_DIR:-$HOME/dev/barbatdev/cortex/cortex-dotfiles}"
LBIN="$HOME/.local/bin"
SHELL_HOME="$HOME/.gentle-shell"
AI_MODULE="github.com/gentleman-programming/gentle-ai/v4/cmd/gentle-ai@main"
SHELL_SNIPPET_DIR="$HOME/.config/cortex-dotfiles/shell"
export PATH="$LBIN:$PATH"
#endregion

#region Helpers
BLOCKERS=()
COMPLETED=()
CURRENT=""

blocker() { BLOCKERS+=("$1"); echo "BLOCKER: $1"; }

# Announce a step; in apply mode remember the previous one as completed.
step() {
  [ -n "$CURRENT" ] && COMPLETED+=("$CURRENT")
  CURRENT="$1"
  echo
  echo "==> $1"
}

fail() {
  echo "FAILED at step: $CURRENT — $*" >&2
  echo "Completed steps:" >&2
  if [ ${#COMPLETED[@]} -eq 0 ]; then echo "  (none)" >&2
  else printf '  %s\n' "${COMPLETED[@]}" >&2; fi
  [ -n "${RETIRE:-}" ] && echo "Retirement dir: $RETIRE" >&2
  exit 1
}

# Print a command; execute it only in apply mode.
run() {
  echo "  \$ $*"
  [ "$APPLY" -eq 1 ] || return 0
  "$@" || fail "'$*' exited $?"
}
#endregion

#region Preflight
echo "Mode: $([ "$APPLY" -eq 1 ] && echo APPLY || echo DRY-RUN)"
echo "Dotfiles: $DOT"
echo "Backup:   $BACKUP"
echo
echo "Preflight:"
[ "$(uname -s)" = "Darwin" ] || blocker "not macOS"
if pgrep -f 'gentle-shell\.mjs|node_modules/gentle-pi' >/dev/null 2>&1; then
  blocker "gentle-shell processes are running (close every session): $(pgrep -f 'gentle-shell\.mjs|node_modules/gentle-pi' | tr '\n' ' ')"
fi
for c in npm go pnpm python3 zsh; do
  command -v "$c" >/dev/null 2>&1 || blocker "command not found: $c"
done
if [ -f "$BACKUP/profiles.json" ]; then
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d.get("profiles"), dict)' \
    "$BACKUP/profiles.json" 2>/dev/null || blocker "$BACKUP/profiles.json is not JSON with a \"profiles\" object"
else
  blocker "missing $BACKUP/profiles.json"
fi
if [ -f "$BACKUP/refactoria.json" ]; then
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$BACKUP/refactoria.json" 2>/dev/null \
    || blocker "$BACKUP/refactoria.json is not valid JSON"
else
  blocker "missing $BACKUP/refactoria.json"
fi
for f in bin/gs-official zsh/scripts/official-gentle-path.zsh; do
  [ -f "$DOT/$f" ] || blocker "missing $DOT/$f"
done
for link in "$LBIN/gs" "$SHELL_SNIPPET_DIR/official-gentle-path.zsh"; do
  # gs is retired in step 3, so only a non-retirable target blocks here.
  if [ "$link" != "$LBIN/gs" ] && { [ -e "$link" ] || [ -L "$link" ]; }; then
    blocker "$link already exists"
  fi
done
[ ${#BLOCKERS[@]} -eq 0 ] && echo "  all checks passed"

if [ "$APPLY" -eq 1 ] && [ ${#BLOCKERS[@]} -gt 0 ]; then
  echo
  echo "Refusing --apply: ${#BLOCKERS[@]} blocker(s). Nothing was changed." >&2
  exit 1
fi
#endregion

#region 1. Managed uninstall (gentle-ai)
step "1. gentle-ai uninstall --all --yes (from an empty temp dir)"
if command -v gentle-ai >/dev/null 2>&1 && [ -x "$(command -v gentle-ai)" ]; then
  if [ "$APPLY" -eq 1 ]; then
    EMPTY="$(mktemp -d)" || fail "mktemp"
    cd "$EMPTY" || fail "cd $EMPTY"
  else
    echo "  \$ cd \"\$(mktemp -d)\""
  fi
  run gentle-ai uninstall --all --yes
  cd "$HOME" || fail "cd $HOME"
else
  echo "  skip: gentle-ai does not resolve to an executable"
fi
#endregion

#region 2. Self-uninstall (shared config kept)
step "2. gentle-shell self-uninstall --yes (never --include-shared)"
if command -v gentle-shell >/dev/null 2>&1; then
  run gentle-shell self-uninstall --yes
else
  echo "  skip: gentle-shell not found"
fi
hash -r
#endregion

#region 3. Retire legacy launchers and Orca
step "3. Retire legacy launchers and Orca extensions"
CANDIDATES=("$LBIN/gs" "$LBIN/gentle-ai" "$HOME/.pi/agent/bin/pi")
for f in "$HOME"/.pi/agent/extensions/orca-*.ts; do
  [ -e "$f" ] || [ -L "$f" ] && CANDIDATES+=("$f")
done
RETIRE=""
if [ "$APPLY" -eq 1 ]; then
  RETIRE="$(mktemp -d "$HOME/gentle-mac-retirement.XXXXXX")" || fail "mktemp retirement dir"
  chmod 700 "$RETIRE" || fail "chmod $RETIRE"
fi
echo "  retirement dir: ${RETIRE:-~/gentle-mac-retirement.XXXXXX (mode 700)}"
for src in "${CANDIDATES[@]}"; do
  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    echo "  absent: $src"; continue
  fi
  if [ -d "$src" ] && [ ! -L "$src" ]; then fail "$src is a directory; refusing"; fi
  if [ ! -f "$src" ] && [ ! -L "$src" ]; then fail "$src has an unexpected type; refusing"; fi
  rel="${src#"$HOME"/}"
  if [ "$APPLY" -eq 1 ]; then
    mkdir -p "$RETIRE/$(dirname "$rel")" || fail "mkdir for $rel"
    mv "$src" "$RETIRE/$rel" || fail "mv $src"
    echo "  moved: $src -> $RETIRE/$rel"
  else
    echo "  would move: $src -> <retirement>/$rel"
  fi
done
hash -r
#endregion

#region 4. Official Shell from npm, main channel
step "4. npm install -g gentle-pi + upgrade to main"
run npm install -g gentle-pi
hash -r
run gentle-shell upgrade --channel main
#endregion

#region 5. Shell setup
step "5. gentle-shell setup"
run gentle-shell setup
#endregion

#region 6. Restore profiles and RefactorIA theme
step "6. Restore profiles.json and RefactorIA into the isolated home"
PROFILES_DST="$SHELL_HOME/gentle-ai/profiles.json"
THEME_DST="$SHELL_HOME/agent/themes/refactoria.json"
SETTINGS="$SHELL_HOME/agent/settings.json"
if [ "$APPLY" -eq 1 ]; then
  if [ ! -e "$PROFILES_DST" ]; then
    mkdir -p "$(dirname "$PROFILES_DST")" || fail "mkdir profiles dir"
    install -m 0600 "$BACKUP/profiles.json" "$PROFILES_DST" || fail "install profiles.json"
    echo "  installed: $PROFILES_DST (0600)"
  elif cmp -s "$BACKUP/profiles.json" "$PROFILES_DST"; then
    echo "  already identical: $PROFILES_DST"
  else
    echo "  WARN: $PROFILES_DST differs from the backup; kept as is (not overwritten)"
  fi
  if [ ! -e "$THEME_DST" ]; then
    mkdir -p "$(dirname "$THEME_DST")" || fail "mkdir themes dir"
    install -m 0644 "$BACKUP/refactoria.json" "$THEME_DST" || fail "install refactoria.json"
    echo "  installed: $THEME_DST (0644)"
  elif cmp -s "$BACKUP/refactoria.json" "$THEME_DST"; then
    echo "  already identical: $THEME_DST"
  else
    fail "$THEME_DST exists and differs; refusing to overwrite"
  fi
  python3 - "$SETTINGS" <<'PY' || fail "set theme in $SETTINGS"
import json, os, stat, sys, tempfile
path = sys.argv[1]
data, mode = {}, 0o600
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
    mode = stat.S_IMODE(os.stat(path).st_mode)
if not isinstance(data, dict):
    sys.exit("settings.json is not a JSON object")
data["theme"] = "refactoria"
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".settings.")
with os.fdopen(fd, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.chmod(tmp, mode)
os.replace(tmp, path)
print(f"  theme set to refactoria in {path}")
PY
else
  echo "  would install: $BACKUP/profiles.json -> $PROFILES_DST (0600, only if absent; WARN if different)"
  echo "  would install: $BACKUP/refactoria.json -> $THEME_DST (0644, refuse if different)"
  echo "  would set: \"theme\": \"refactoria\" in $SETTINGS (atomic, other keys and mode kept)"
fi
#endregion

#region 7. External Gentle AI for Claude Code
step "7. go install gentle-ai@main + install for Claude Code"
echo "  \$ GOBIN=$LBIN go install $AI_MODULE"
if [ "$APPLY" -eq 1 ]; then
  GOBIN="$LBIN" go install "$AI_MODULE" || fail "go install exited $?"
  [ -f "$LBIN/gentle-ai" ] && [ ! -L "$LBIN/gentle-ai" ] && [ -x "$LBIN/gentle-ai" ] \
    || fail "$LBIN/gentle-ai is not a regular executable"
fi
run "$LBIN/gentle-ai" install --agent claude-code
#endregion

#region 8. Dotfiles links
step "8. Link gs-official and official-gentle-path.zsh"
for link in "$LBIN/gs" "$SHELL_SNIPPET_DIR/official-gentle-path.zsh"; do
  if [ "$APPLY" -eq 1 ] && { [ -e "$link" ] || [ -L "$link" ]; }; then
    fail "$link already exists; refusing"
  fi
done
run mkdir -p "$SHELL_SNIPPET_DIR"
run ln -s "$DOT/bin/gs-official" "$LBIN/gs"
run ln -s "$DOT/zsh/scripts/official-gentle-path.zsh" "$SHELL_SNIPPET_DIR/official-gentle-path.zsh"
#endregion

#region 9. Verify
step "9. Verify in a fresh interactive zsh"
echo "  \$ zsh -ic 'whence -p gs gentle-shell gentle-ai codegraph go'"
echo "  \$ gentle-shell --version; gentle-ai version; go version -m $LBIN/gentle-ai"
if [ "$APPLY" -eq 1 ]; then
  resolved="$(zsh -ic 'whence -p gs gentle-shell gentle-ai codegraph go' 2>/dev/null | grep '^/')"
  while IFS= read -r line; do echo "  $line"; done <<<"$resolved"
  [ "$(echo "$resolved" | grep -c '^/')" -eq 5 ] || fail "not every command resolves in zsh"
  gentle-shell --version || fail "gentle-shell --version"
  "$LBIN/gentle-ai" version || fail "gentle-ai version"
  go version -m "$LBIN/gentle-ai" | grep -E '^\s*(path|mod)'
fi
COMPLETED+=("$CURRENT")
#endregion

echo
if [ "$APPLY" -eq 1 ]; then
  echo "Done. Retirement dir: $RETIRE"
  echo "Next: open a new terminal, run 'gs', then '/login', then check '/gentle:profiles'."
else
  echo "Dry-run finished; nothing changed. ${#BLOCKERS[@]} blocker(s)."
  echo "Re-run with --apply from a plain terminal once there are no blockers."
fi
exit 0
