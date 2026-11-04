package main

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Org is the GitHub organization of every Gentle repository gs manages.
const Org = "Gentleman-Programming"

// Managed binaries: gs is their only installer and places them as regular
// files in BinDir. Nothing else may replace them (see quarantine in sync.go).
var Managed = []Binary{
	{Name: "gentle-ai", Repo: "gentle-ai", Module: "github.com/gentleman-programming/gentle-ai/v4", Pkg: "cmd/gentle-ai"},
	{Name: "engram", Repo: "engram", Module: "github.com/Gentleman-Programming/engram/v3", Pkg: "cmd/engram"},
}

// Binary is one Go binary gs builds from a pinned commit.
type Binary struct {
	Name   string
	Repo   string
	Module string
	Pkg    string
}

// ImportPath is the `go install` path without a version.
func (b Binary) ImportPath() string { return b.Module + "/" + b.Pkg }

// Env holds every path gs reads or writes; tests point Home at a temp dir.
type Env struct {
	Home   string
	Stdout io.Writer
	Stderr io.Writer
	// Extra environment for child processes, "KEY=VALUE".
	ChildEnv []string
}

func newEnv() *Env {
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		fmt.Fprintln(os.Stderr, "gs: cannot resolve HOME")
		os.Exit(1)
	}
	return &Env{Home: home, Stdout: os.Stdout, Stderr: os.Stderr}
}

func (e *Env) BinDir() string     { return filepath.Join(e.Home, ".local", "bin") }
func (e *Env) StateDir() string   { return filepath.Join(e.Home, ".local", "share", "gs") }
func (e *Env) Clones() string     { return filepath.Join(e.Home, "dev", "gentle") }
func (e *Env) Trees() string      { return filepath.Join(e.Home, "dev", "worktrees") }
func (e *Env) Quarantine() string { return filepath.Join(e.StateDir(), "quarantine") }

// DotfilesDir is the dotfiles clone gs sync pulls (CORTEX_DOTFILES_DIR overrides).
func (e *Env) DotfilesDir() string {
	if d := os.Getenv("CORTEX_DOTFILES_DIR"); d != "" {
		return d
	}
	return filepath.Join(e.Home, "dev", "barbatdev", "cortex", "cortex-dotfiles")
}

// Target is where a managed binary lives.
func (e *Env) Target(name string) string { return filepath.Join(e.BinDir(), name) }

// environ is the child environment: ours plus ChildEnv overrides (last wins).
func (e *Env) environ() []string {
	env := os.Environ()
	if len(e.ChildEnv) == 0 {
		return env
	}
	keys := map[string]bool{}
	for _, kv := range e.ChildEnv {
		keys[strings.SplitN(kv, "=", 2)[0]] = true
	}
	out := make([]string, 0, len(env)+len(e.ChildEnv))
	for _, kv := range env {
		if !keys[strings.SplitN(kv, "=", 2)[0]] {
			out = append(out, kv)
		}
	}
	return append(out, e.ChildEnv...)
}

// Output runs a command and returns its trimmed combined output.
func (e *Env) Output(dir, name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Env = e.environ()
	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = &buf
	err := cmd.Run()
	return strings.TrimSpace(buf.String()), err
}

// Stdout runs a command and returns only its trimmed stdout.
func (e *Env) StdoutOf(dir, name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Env = e.environ()
	out, err := cmd.Output()
	return strings.TrimSpace(string(out)), err
}

// Run runs a command attached to the terminal.
func (e *Env) Run(dir, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Env = e.environ()
	cmd.Stdin = os.Stdin
	cmd.Stdout = e.Stdout
	cmd.Stderr = e.Stderr
	return cmd.Run()
}

// Fail is a user-facing error: gs prints "gs: <msg>" and exits 1.
type Fail string

func (f Fail) Error() string { return string(f) }

func failf(format string, a ...any) error { return Fail(fmt.Sprintf(format, a...)) }

// indent prefixes every line of s for nested command output.
func indent(s, prefix string) string {
	if s == "" {
		return ""
	}
	lines := strings.Split(strings.TrimRight(s, "\n"), "\n")
	for i, l := range lines {
		lines[i] = prefix + l
	}
	return strings.Join(lines, "\n") + "\n"
}
