package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const (
	aiSHA     = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	engramSHA = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	shellSHA  = "abcdef1234567890abcdef1234567890abcdef12"
)

// consumerHost is a Mac/agent-dev style host: no clones, gentle-shell on PATH.
// The go stub "builds" stubs into $GOBIN; ENGRAM_BUILD_PRE_V3=1 builds a v1.
func consumerHost(t *testing.T) *sandbox {
	s := newSandbox(t)
	s.healthy()
	t.Setenv("GS_SKIP_DOTFILES", "1")
	s.stub("gh", `case "$*" in
  "auth status") exit 0 ;;
  "auth token") echo tok ;;
  "api repos/Gentleman-Programming/gentle-ai/commits/main --jq .sha") echo `+aiSHA+` ;;
  "api repos/Gentleman-Programming/engram/commits/main --jq .sha") echo `+engramSHA+` ;;
  "api repos/Gentleman-Programming/gentle-pi/commits/main --jq .sha") echo `+shellSHA+` ;;
  *) echo "gh $*" >> "$CALLS" ;;
esac`)
	s.stub("go", `[ "$1 $2" = "env GOBIN" ] && { echo "${GOBIN:-}"; exit 0; }
echo "go $* GOBIN=$GOBIN" >> "$CALLS"
[ "$1" = install ] || exit 0
mkdir -p "$GOBIN"
case "$2" in
  *engram*) if [ "${ENGRAM_BUILD_PRE_V3:-}" = 1 ]; then id="exit 1"; v=1.20.1; else id="echo abc"; v=3.7.0; fi
    printf '#!/bin/sh\ncase "$1" in version) echo "engram %s";; instance-id) %s;; esac\n' "$v" "$id" > "$GOBIN/engram" ;;
  *gentle-ai*) printf '#!/bin/sh\ncase "$1" in --version|version) echo "gentle-ai 4.4.0";; *) echo "gentle-ai $* engram=$GENTLE_AI_ENGRAM_BIN GOBIN=$GOBIN" >> "$CALLS";; esac\n' > "$GOBIN/gentle-ai" ;;
esac
chmod +x "$GOBIN"/*`)
	s.stub("gentle-shell", `case "$1" in
  --version) echo "gentle-shell 4.5.1-main.abcdef123456" ;;
  upgrade) echo "upgrade GOBIN=$GOBIN token=${GH_TOKEN:-}" >> "$CALLS"
    [ -n "${UPGRADE_STRAY:-}" ] && { mkdir -p "$GOBIN"; echo v1 > "$GOBIN/engram"; }
    exit "${UPGRADE_RC:-0}" ;;
esac`)
	return s
}

func runSync(s *sandbox) error {
	s.out.Reset()
	return cmdSync(s.env)
}

func fileBody(t *testing.T, p string) string {
	t.Helper()
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func TestSyncBuildsPinnedMainCommitsAsRegularFiles(t *testing.T) {
	s := consumerHost(t)
	if err := runSync(s); err != nil {
		t.Fatalf("sync failed: %v\n%s", err, s.out.String())
	}
	calls := s.readCalls()
	contains(t, calls, "go install github.com/gentleman-programming/gentle-ai/v4/cmd/gentle-ai@"+aiSHA)
	contains(t, calls, "go install github.com/Gentleman-Programming/engram/v3/cmd/engram@"+engramSHA)
	for _, n := range []string{"engram", "gentle-ai"} {
		fi, err := os.Lstat(s.env.Target(n))
		if err != nil || !fi.Mode().IsRegular() {
			t.Fatalf("%s must be a regular file: %v", n, err)
		}
	}
	contains(t, fileBody(t, s.env.Target("engram")), "engram 3.7.0")
	contains(t, s.out.String(), "engram (3.6.2 -> 3.7.0)")
}

func TestSyncReplacesSymlinkedBinaries(t *testing.T) {
	s := consumerHost(t)
	real := filepath.Join(s.home, "elsewhere", "engram")
	s.script(real, engramBody("3.6.2", false))
	os.Remove(s.env.Target("engram"))
	os.Symlink(real, s.env.Target("engram"))
	if err := runSync(s); err != nil {
		t.Fatalf("sync failed: %v\n%s", err, s.out.String())
	}
	fi, _ := os.Lstat(s.env.Target("engram"))
	if fi.Mode()&os.ModeSymlink != 0 {
		t.Fatal("engram must no longer be a symlink")
	}
	contains(t, fileBody(t, real), "engram 3.6.2") // the link target is left alone
}

func TestSyncQuarantinesStrayInstallsFromOtherSteps(t *testing.T) {
	s := consumerHost(t)
	t.Setenv("UPGRADE_STRAY", "1")
	t.Setenv("GOBIN", s.env.BinDir()) // the host's own go env pointing at ~/.local/bin
	err := runSync(s)
	contains(t, s.readCalls(), "upgrade GOBIN="+s.env.Quarantine())
	contains(t, fileBody(t, s.env.Target("engram")), "engram 3.7.0")
	contains(t, s.out.String(), "WARN quarantine")
	if err != nil {
		t.Fatalf("a quarantined stray install is a warning, not a failure: %v\n%s", err, s.out.String())
	}
}

func TestSyncNeverInstallsAPreV3Engram(t *testing.T) {
	s := consumerHost(t)
	t.Setenv("ENGRAM_BUILD_PRE_V3", "1")
	if runSync(s) == nil {
		t.Fatal("a pre-v3 engram build must fail the sync")
	}
	contains(t, s.out.String(), "INCOMPLETE")
	contains(t, s.out.String(), "engram build")
	contains(t, fileBody(t, s.env.Target("engram")), "engram 3.6.2") // old one kept
}

func TestSyncGentleAiUsesOurEngramAndQuarantinedGOBIN(t *testing.T) {
	s := consumerHost(t)
	if err := runSync(s); err != nil {
		t.Fatalf("sync failed: %v\n%s", err, s.out.String())
	}
	contains(t, s.readCalls(), "gentle-ai sync --agents claude-code engram="+s.env.Target("engram")+" GOBIN="+s.env.Quarantine())
}

func TestSyncPassesGhTokenToGentleShell(t *testing.T) {
	s := consumerHost(t)
	runSync(s)
	contains(t, s.readCalls(), "token=tok")
}

func TestSyncFailedUpgradeIsIncompleteButBinariesStillUpdate(t *testing.T) {
	s := consumerHost(t)
	t.Setenv("UPGRADE_RC", "1")
	if runSync(s) == nil {
		t.Fatal("failed upgrade must make sync fail")
	}
	contains(t, s.out.String(), "gentle-shell upgrade (main)")
	contains(t, s.out.String(), "INCOMPLETE")
	contains(t, fileBody(t, s.env.Target("engram")), "engram 3.7.0")
}

func TestSyncRefusesBeforeChangingAnythingWithoutGh(t *testing.T) {
	s := consumerHost(t)
	s.stub("gh", `exit 1`)
	err := runSync(s)
	if err == nil {
		t.Fatal("sync without gh auth must fail")
	}
	if strings.Contains(s.readCalls(), "go install") || strings.Contains(s.readCalls(), "upgrade") {
		t.Fatalf("nothing may run before preflight passes:\n%s", s.readCalls())
	}
	contains(t, err.Error(), "gh auth")
}

func TestSyncRestartsEngramServiceWhenEngramChanged(t *testing.T) {
	s := consumerHost(t)
	s.stub("systemctl", `echo "systemctl $*" >> "$CALLS"; exit 0`)
	s.stub("launchctl", `echo "launchctl $*" >> "$CALLS"; [ "$1" = list ] && echo "1 0 com.gentleman-programming.engram"; exit 0`)
	if err := runSync(s); err != nil {
		t.Fatalf("sync failed: %v\n%s", err, s.out.String())
	}
	calls := s.readCalls()
	if !strings.Contains(calls, "systemctl --user restart engram.service") && !strings.Contains(calls, "launchctl kickstart -k") {
		t.Fatalf("engram service must be restarted:\n%s", calls)
	}
}

func TestSyncSecondRunChangesNothing(t *testing.T) {
	s := consumerHost(t)
	runSync(s)
	if err := runSync(s); err != nil {
		t.Fatalf("second sync failed: %v\n%s", err, s.out.String())
	}
	contains(t, s.out.String(), "nothing changed")
}
