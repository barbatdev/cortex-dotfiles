package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// sandbox is a throwaway HOME plus a stub dir first on PATH. Stubs are shell
// scripts, so tests run offline and never touch real binaries.
type sandbox struct {
	t     *testing.T
	home  string
	stubs string
	calls string
	out   bytes.Buffer
	env   *Env
}

func newSandbox(t *testing.T) *sandbox {
	t.Helper()
	root := t.TempDir()
	s := &sandbox{t: t, home: filepath.Join(root, "home"), stubs: filepath.Join(root, "stubs"), calls: filepath.Join(root, "calls")}
	for _, d := range []string{s.stubs, filepath.Join(s.home, ".local", "bin")} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("HOME", s.home)
	t.Setenv("PATH", s.stubs+":"+filepath.Join(s.home, ".local", "bin")+":/usr/bin:/bin:/usr/sbin:/sbin")
	t.Setenv("CALLS", s.calls)
	t.Setenv("GOBIN", "")
	s.env = &Env{Home: s.home, Stdout: &s.out, Stderr: &s.out}
	return s
}

// script writes an executable shell script at path.
func (s *sandbox) script(path, body string) {
	s.t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		s.t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("#!/bin/sh\n"+body+"\n"), 0o755); err != nil {
		s.t.Fatal(err)
	}
}

func (s *sandbox) stub(name, body string) { s.script(filepath.Join(s.stubs, name), body) }

// engramBody is a v3 engram stub; preV3 makes instance-id fail like Engram v1.
func engramBody(version string, preV3 bool) string {
	id := "echo abc"
	if preV3 {
		id = "echo 'unknown command'; exit 1"
	}
	return `case "$1" in
  version) echo "engram ` + version + `" ;;
  instance-id) ` + id + ` ;;
  serve|mcp) exit 0 ;;
esac`
}

func aiBody(version string) string {
	return `case "$1" in
  --version|version) echo "gentle-ai ` + version + `" ;;
  *) echo "gentle-ai $*" >> "$CALLS" ;;
esac`
}

// healthy installs everything doctor expects on a good host.
func (s *sandbox) healthy() {
	s.script(s.env.Target("engram"), engramBody("3.6.2", false))
	s.script(s.env.Target("gentle-ai"), aiBody("4.3.2"))
	s.stub("gh", `[ "$1 $2" = "auth status" ] && exit 0; [ "$1 $2" = "auth token" ] && { echo tok; exit 0; }; echo "gh $*" >> "$CALLS"`)
	s.stub("gentle-shell", `[ "$1" = --version ] && echo "gentle-shell 4.5.1-main.abcdef123456"; exit 0`)
	s.stub("go", `[ "$1 $2" = "env GOBIN" ] && { echo "${GOBIN:-}"; exit 0; }; echo "go $* GOBIN=${GOBIN:-}" >> "$CALLS"`)
	s.stub("pgrep", `exit 1`)
	// Never reach the real service managers from a test.
	s.stub("launchctl", `echo "launchctl $*" >> "$CALLS"; exit 0`)
	s.stub("systemctl", `echo "systemctl $*" >> "$CALLS"; exit 0`)
	s.stub("lsof", `exit 1`)
}

func (s *sandbox) readCalls() string {
	b, _ := os.ReadFile(s.calls)
	return string(b)
}

func contains(t *testing.T, got, want string) {
	t.Helper()
	if !strings.Contains(got, want) {
		t.Fatalf("want output containing %q, got:\n%s", want, got)
	}
}

func notContains(t *testing.T, got, bad string) {
	t.Helper()
	if strings.Contains(got, bad) {
		t.Fatalf("output must not contain %q, got:\n%s", bad, got)
	}
}
