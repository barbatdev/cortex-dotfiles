package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Repos are the Gentle repositories gs manages clones and worktrees for.
var Repos = []string{"gentle-ai", "gentle-shell", "engram"}

// isWorkshop: a host with clean clones in ~/dev/gentle (agent-gentle). Pi
// loads the gentle-shell clone and binaries build from the local clones.
func isWorkshop(e *Env) bool {
	url, err := e.StdoutOf("", "git", "-C", filepath.Join(e.Clones(), "gentle-shell"), "remote", "get-url", "origin")
	return err == nil && strings.Contains(url, Org+"/gentle-shell")
}

// pullClones fast-forwards every clean clone to origin/main and returns the
// build sources pinned to the resulting HEADs.
func (s *syncRun) pullClones() map[string]source {
	out := map[string]source{}
	for _, repo := range Repos {
		dir := filepath.Join(s.e.Clones(), repo)
		label := repo + " clone"
		if !isDir(filepath.Join(dir, ".git")) {
			s.step(label, fmt.Errorf("missing clean clone %s", dir), "")
			continue
		}
		// Untracked files (.engram/, odd/ left by sessions) survive checkout and
		// pull untouched; only tracked edits would be at risk.
		if st, _ := s.e.StdoutOf(dir, "git", "status", "--porcelain", "--untracked-files=no"); st != "" {
			s.step(label, fmt.Errorf("%s has local changes; clean clones only", dir), "")
			continue
		}
		var err error
		var msg string
		for _, args := range [][]string{
			{"checkout", "-q", "main"},
			{"fetch", "-q", "--tags", "origin"},
			{"pull", "-q", "--ff-only", "origin", "main"},
		} {
			if msg, err = s.e.Output(dir, "git", args...); err != nil {
				break
			}
		}
		if !s.step(label, err, msg) {
			continue
		}
		sha, _ := s.e.StdoutOf(dir, "git", "rev-parse", "HEAD")
		for _, b := range Managed {
			if b.Repo == repo {
				out[b.Name] = source{sha: sha, clone: dir}
			}
		}
	}
	return out
}

// workshopDeps installs the clones' JS dependencies and registers our
// gentle-ai where the gentle-shell launcher reads it.
func (s *syncRun) workshopDeps() {
	shell := filepath.Join(s.e.Clones(), "gentle-shell")
	out, err := s.e.Output(shell, "pnpm", "install", "--frozen-lockfile", "--silent")
	s.step("gentle-shell pnpm install", err, out)
	plugin := filepath.Join(s.e.Clones(), "engram", "plugin", "pi")
	if isDir(plugin) {
		out, err := s.e.Output(plugin, "npm", "install", "--no-save", "--no-audit", "--no-fund", "--omit=peer", "--silent")
		s.step("engram pi plugin npm install", err, out)
	}
	s.step("gentle-ai dev-binary registration", registerDevBinary(s.e), "")
}

// DevBinaryRegistration is install-level state the official launcher reads
// from ~/.pi/gentle-ai even in the isolated home.
func (e *Env) DevBinaryRegistration() string {
	return filepath.Join(e.Home, ".pi", "gentle-ai", "dev-binary.json")
}

func registerDevBinary(e *Env) error {
	reg := e.DevBinaryRegistration()
	if err := os.MkdirAll(filepath.Dir(reg), 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(reg), ".dev-binary.")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	_, err = fmt.Fprintf(tmp, "{\"schema\":\"gentle-pi.dev-binary/v1\",\"path\":%q}\n", e.Target("gentle-ai"))
	if err == nil {
		err = tmp.Chmod(0o600)
	}
	if cerr := tmp.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return err
	}
	return os.Rename(tmp.Name(), reg)
}
