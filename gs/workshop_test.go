package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func git(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir, "-c", "user.email=t@t", "-c", "user.name=t"}, args...)...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return strings.TrimSpace(string(out))
}

// workshopHost has clean clones of the three repos with a bare origin each,
// under a path that keeps the Gentleman-Programming name.
func workshopHost(t *testing.T) *sandbox {
	s := newSandbox(t)
	s.healthy()
	t.Setenv("GS_SKIP_DOTFILES", "1")
	origins := filepath.Join(filepath.Dir(s.home), Org)
	for _, r := range Repos {
		c := filepath.Join(s.env.Clones(), r)
		os.MkdirAll(c, 0o755)
		git(t, c, "init", "-q", "-b", "main")
		git(t, c, "commit", "-q", "--allow-empty", "-m", "init")
		bare := filepath.Join(origins, r+".git")
		git(t, c, "clone", "-q", "--bare", c, bare)
		git(t, c, "remote", "add", "origin", bare)
		git(t, c, "fetch", "-q", "origin")
	}
	os.MkdirAll(filepath.Join(s.env.Clones(), "engram", "plugin", "pi"), 0o755)
	s.stub("go", `[ "$1 $2" = "env GOBIN" ] && { echo "${GOBIN:-}"; exit 0; }
echo "go $* pwd=$(pwd)" >> "$CALLS"
[ "$1" = build ] || exit 0
out="$4"; mkdir -p "$(dirname "$out")"
case "$out" in
  */engram) printf '#!/bin/sh\ncase "$1" in version) echo "engram 3.8.0";; instance-id) echo x;; esac\n' > "$out" ;;
  */gentle-ai) printf '#!/bin/sh\ncase "$1" in --version|version) echo "gentle-ai 4.5.0";; *) echo "gentle-ai $*" >> "$CALLS";; esac\n' > "$out" ;;
esac
chmod +x "$out"`)
	for _, b := range []string{"pnpm", "npm", "node"} {
		s.stub(b, `echo "`+b+` $*" >> "$CALLS"`)
	}
	return s
}

func TestWorkshopSyncBuildsFromLocalClones(t *testing.T) {
	s := workshopHost(t)
	if err := runSync(s); err != nil {
		t.Fatalf("workshop sync failed: %v\n%s", err, s.out.String())
	}
	calls := s.readCalls()
	contains(t, s.out.String(), "workshop (local clones)")
	contains(t, calls, "go build -trimpath -o")
	contains(t, calls, "/home/dev/gentle/engram\n")
	notContains(t, calls, "go install")
	notContains(t, calls, "upgrade")
	contains(t, fileBody(t, s.env.Target("engram")), "engram 3.8.0")
	contains(t, calls, "gentle-shell.mjs --isolated setup")
	reg := fileBody(t, s.env.DevBinaryRegistration())
	contains(t, reg, `"path":"`+s.env.Target("gentle-ai")+`"`)
	if fi, _ := os.Stat(s.env.DevBinaryRegistration()); fi.Mode().Perm() != 0o600 {
		t.Fatalf("registration must be 0600, is %v", fi.Mode().Perm())
	}
}

func TestWorkshopSyncRefusesDirtyClone(t *testing.T) {
	s := workshopHost(t)
	c := filepath.Join(s.env.Clones(), "engram")
	os.WriteFile(filepath.Join(c, "f"), []byte("x"), 0o644)
	git(t, c, "add", "f")
	if runSync(s) == nil {
		t.Fatal("a dirty clone must fail the sync")
	}
	contains(t, s.out.String(), "has local changes; clean clones only")
	contains(t, fileBody(t, s.env.Target("engram")), "engram 3.6.2")
}
