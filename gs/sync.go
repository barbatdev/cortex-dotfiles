package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
)

// syncRun carries one gs sync: step results and what changed.
type syncRun struct {
	e       *Env
	failed  []string
	changed []string
}

func (s *syncRun) step(label string, err error, out string) bool {
	if err == nil {
		fmt.Fprintf(s.e.Stdout, "  %-34s ok\n", label)
		return true
	}
	fmt.Fprintf(s.e.Stdout, "  %-34s FAILED\n", label)
	fmt.Fprint(s.e.Stdout, indent(out, "      "))
	if out == "" {
		fmt.Fprint(s.e.Stdout, indent(err.Error(), "      "))
	}
	s.failed = append(s.failed, label)
	return false
}

func (s *syncRun) skip(label, why string) {
	fmt.Fprintf(s.e.Stdout, "  %-34s skipped (%s)\n", label, why)
}

// cmdSync brings gentle-shell, gentle-ai and Engram to main.
//
// Determinism rules:
//   - gentle-ai and engram are built by gs only, from the commit resolved once
//     (GitHub main through gh, or the clean local clone on workshop hosts), and
//     land in ~/.local/bin as regular files through an atomic rename.
//   - Every other step runs with GOBIN pointed at a quarantine dir, so a
//     `go install` done by gentle-shell or gentle-ai can never replace them.
//   - The sync ends with the same checks as gs doctor; any failure is INCOMPLETE.
func cmdSync(e *Env) error {
	s := &syncRun{e: e}
	ws := isWorkshop(e)
	mode := "consumer (GitHub main through gh)"
	if ws {
		mode = "workshop (local clones)"
	}
	fmt.Fprintf(e.Stdout, "gs sync — %s\n", mode)

	token, err := preflight(e, ws)
	if err != nil {
		return err
	}
	// Children of the sync: GitHub through our gh token, Engram through our
	// binary, stray Go installs into quarantine.
	os.RemoveAll(e.Quarantine())
	if err := os.MkdirAll(e.Quarantine(), 0o755); err != nil {
		return err
	}
	e.ChildEnv = append(e.ChildEnv,
		"GOBIN="+e.Quarantine(),
		"GH_TOKEN="+token, "GITHUB_TOKEN="+token,
		"GENTLE_AI_ENGRAM_BIN="+e.Target("engram"),
		"GENTLE_SHELL_NO_AUTO_SETUP=1",
	)

	before := versions(e)
	var sources map[string]source
	if ws {
		sources = s.pullClones()
	} else {
		sources = s.resolveMain()
		s.upgradeShell(before["gentle-shell"])
	}

	engramChanged := false
	for _, b := range Managed {
		src, ok := sources[b.Name]
		if !ok {
			continue
		}
		changed, err := s.buildAndInstall(b, src)
		if err == nil && changed && b.Name == "engram" {
			engramChanged = true
		}
	}
	if ws {
		s.workshopDeps()
	}
	s.aiSync(ws)
	if engramChanged || len(staleEngramProcesses(e)) > 0 {
		restartEngramService(s)
	}
	if s.syncDotfiles() {
		s.rebuildSelf()
	}
	if !ws {
		s.syncAppRepos()
	}

	after := versions(e)
	for _, name := range []string{"gentle-shell", "gentle-ai", "engram"} {
		if before[name] != "" && after[name] != "" && before[name] != after[name] {
			s.changed = append(s.changed, fmt.Sprintf("%s (%s -> %s)", name, before[name], after[name]))
		}
	}
	fmt.Fprintf(e.Stdout, "\nversions: shell %s | gentle-ai %s | engram %s\n", orQ(after["gentle-shell"]), orQ(after["gentle-ai"]), orQ(after["engram"]))
	if !ws {
		s.checkShellFresh(after["gentle-shell"])
	}

	fmt.Fprintln(e.Stdout, "\nchecks:")
	r := &report{env: e}
	checkHost(e, r)
	s.failed = append(s.failed, r.fails...)

	if len(s.failed) > 0 {
		fmt.Fprintf(e.Stdout, "\nINCOMPLETE — failed: %s\n", strings.Join(s.failed, "; "))
		if len(s.changed) > 0 {
			fmt.Fprintf(e.Stdout, "changed anyway: %s\n  Restart Pi to pick them up.\n", strings.Join(s.changed, ", "))
		}
		return failf("sync incomplete")
	}
	if len(s.changed) > 0 {
		fmt.Fprintf(e.Stdout, "\nchanged: %s\n  Restart Pi to pick them up.\n", strings.Join(s.changed, ", "))
	} else {
		fmt.Fprintln(e.Stdout, "\nnothing changed — no Pi restart needed.")
	}
	return nil
}

// preflight checks every tool before anything changes and returns the gh token.
func preflight(e *Env, ws bool) (string, error) {
	if out, err := e.Output("", "gh", "auth", "status"); err != nil {
		return "", failf("gh auth: gh is not authenticated (run: gh auth login): %s", firstLine(out))
	}
	token, err := e.StdoutOf("", "gh", "auth", "token")
	if err != nil || token == "" {
		return "", failf("gh auth: cannot read the gh token")
	}
	if _, err := exec.LookPath("go"); err != nil {
		return "", failf("go not found on PATH")
	}
	if !ws {
		if _, err := exec.LookPath("gentle-shell"); err != nil {
			return "", failf("gentle-shell not found on PATH; install it first")
		}
	}
	if err := os.MkdirAll(e.BinDir(), 0o755); err != nil {
		return "", err
	}
	return token, nil
}

// source is where a managed binary is built from.
type source struct {
	sha   string // pinned commit
	clone string // workshop: local clone dir (built with go build); empty = go install @sha
}

func (s *syncRun) resolveMain() map[string]source {
	out := map[string]source{}
	for _, b := range Managed {
		sha, err := s.e.StdoutOf("", "gh", "api", "repos/"+Org+"/"+b.Repo+"/commits/main", "--jq", ".sha")
		if err != nil || len(sha) < 7 {
			s.step(b.Name+" main commit", fmt.Errorf("gh api did not return %s main", b.Repo), sha)
			continue
		}
		out[b.Name] = source{sha: sha}
	}
	return out
}

// buildAndInstall builds b into a staging dir, verifies it, then atomically
// replaces ~/.local/bin/<name>. Reports whether the installed bytes changed.
func (s *syncRun) buildAndInstall(b Binary, src source) (bool, error) {
	label := fmt.Sprintf("%s build (%s)", b.Name, short(src.sha))
	stage, err := os.MkdirTemp(s.e.StateDir(), "build-")
	if err != nil {
		os.MkdirAll(s.e.StateDir(), 0o755)
		if stage, err = os.MkdirTemp(s.e.StateDir(), "build-"); err != nil {
			s.step(label, err, "")
			return false, err
		}
	}
	defer os.RemoveAll(stage)
	built := filepath.Join(stage, b.Name)
	var out string
	if src.clone != "" {
		out, err = s.e.Output(src.clone, "go", "build", "-trimpath", "-o", built, "./"+b.Pkg)
	} else {
		s.e.ChildEnv = append(s.e.ChildEnv, "GOBIN="+stage)
		out, err = s.e.Output("", "go", "install", b.ImportPath()+"@"+src.sha)
		s.e.ChildEnv = append(s.e.ChildEnv, "GOBIN="+s.e.Quarantine())
	}
	if err == nil {
		err = verifyBuilt(s.e, b, built)
		if err != nil {
			out = err.Error()
		}
	}
	if !s.step(label, err, out) {
		return false, err
	}
	changed, err := installAtomic(built, s.e.Target(b.Name))
	if err != nil {
		s.step(b.Name+" install", err, "")
		return false, err
	}
	return changed, nil
}

// verifyBuilt rejects a build before it can replace the installed binary.
func verifyBuilt(e *Env, b Binary, path string) error {
	if _, err := os.Stat(path); err != nil {
		return fmt.Errorf("build produced no %s", path)
	}
	if b.Name == "engram" {
		if out, err := e.Output("", path, "instance-id"); err != nil {
			return fmt.Errorf("built engram has no instance-id (pre-v3): %s", firstLine(out))
		}
	}
	if _, err := e.Output("", path, "version"); err != nil {
		return fmt.Errorf("built %s does not run", b.Name)
	}
	return nil
}

// installAtomic copies src next to dst and renames it over dst, so dst is
// always either the old or the new regular file. A symlink at dst is replaced
// by the file, never followed.
func installAtomic(src, dst string) (bool, error) {
	if same, _ := sameContent(src, dst); same {
		if fi, err := os.Lstat(dst); err == nil && fi.Mode().IsRegular() {
			return false, nil
		}
	}
	tmp, err := os.CreateTemp(filepath.Dir(dst), "."+filepath.Base(dst)+".gs-")
	if err != nil {
		return false, err
	}
	defer os.Remove(tmp.Name())
	in, err := os.Open(src)
	if err != nil {
		tmp.Close()
		return false, err
	}
	_, err = io.Copy(tmp, in)
	in.Close()
	if err == nil {
		err = tmp.Chmod(0o755)
	}
	if err == nil {
		err = tmp.Sync()
	}
	if cerr := tmp.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return false, err
	}
	return true, os.Rename(tmp.Name(), dst)
}

func sameContent(a, b string) (bool, error) {
	ha, err := fileSHA(a)
	if err != nil {
		return false, err
	}
	hb, err := fileSHA(b)
	if err != nil {
		return false, err
	}
	return ha == hb, nil
}

func fileSHA(p string) (string, error) {
	f, err := os.Open(p) // follows symlinks: content comparison only
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// aiSync materializes the managed configs every runtime reads.
// GS_SYNC_AGENTS scopes runtimes (default claude-code); GS_SKIP_AI_SYNC=1 skips.
func (s *syncRun) aiSync(ws bool) {
	if os.Getenv("GS_SKIP_AI_SYNC") == "1" {
		s.skip("gentle-ai sync", "GS_SKIP_AI_SYNC=1")
		return
	}
	agents := os.Getenv("GS_SYNC_AGENTS")
	if agents == "" {
		agents = "claude-code"
	}
	out, err := s.e.Output("", s.e.Target("gentle-ai"), "sync", "--agents", agents)
	if s.step("gentle-ai sync", err, out) {
		if n := syncedFiles(out); n > 0 {
			s.changed = append(s.changed, fmt.Sprintf("managed configs (%d files)", n))
		}
	}
	if ws {
		shell := filepath.Join(s.e.Clones(), "gentle-shell")
		out, err := s.e.Output(shell, "node", filepath.Join(shell, "bin", "gentle-shell.mjs"), "--isolated", "setup")
		s.step("gentle-shell setup (isolated home)", err, out)
	}
}

func syncedFiles(out string) int {
	for _, l := range strings.Split(out, "\n") {
		if rest, ok := strings.CutPrefix(strings.TrimSpace(l), "Sync actions executed: "); ok {
			n, _ := strconv.Atoi(strings.Fields(rest)[0])
			return n
		}
	}
	return 0
}

// restartEngramService restarts the Engram server so it runs the new binary.
// Agent MCP children keep the old one until reconnected (/mcp).
func restartEngramService(s *syncRun) {
	label := "engram service restart"
	if runtime.GOOS == "darwin" {
		list, _ := s.e.StdoutOf("", "launchctl", "list")
		if !strings.Contains(list, "com.gentleman-programming.engram") {
			s.skip(label, "no LaunchAgent com.gentleman-programming.engram")
			return
		}
		out, err := s.e.Output("", "launchctl", "kickstart", "-k", "gui/"+strconv.Itoa(os.Getuid())+"/com.gentleman-programming.engram")
		s.step(label, err, out)
		return
	}
	if _, err := exec.LookPath("systemctl"); err != nil {
		s.skip(label, "no systemctl")
		return
	}
	if out, err := s.e.Output("", "systemctl", "--user", "cat", "engram.service"); err != nil {
		s.skip(label, "no engram.service: "+firstLine(out))
		return
	}
	out, err := s.e.Output("", "systemctl", "--user", "restart", "engram.service")
	s.step(label, err, out)
}

// syncDotfiles pulls the dotfiles clone when it is clean and on main, and
// reports whether the clone is now current main (gs may rebuild from it).
func (s *syncRun) syncDotfiles() bool {
	const label = "dotfiles"
	dir := s.e.DotfilesDir()
	switch {
	case os.Getenv("GS_SKIP_DOTFILES") == "1":
		s.skip(label, "GS_SKIP_DOTFILES=1")
		return false
	case !isDir(filepath.Join(dir, ".git")):
		s.skip(label, "no clone at "+dir)
		return false
	}
	if st, _ := s.e.StdoutOf(dir, "git", "status", "--porcelain"); st != "" {
		s.skip(label, dir+" has local changes")
		return false
	}
	if br, _ := s.e.StdoutOf(dir, "git", "branch", "--show-current"); br != "main" {
		s.skip(label, fmt.Sprintf("%s is on %q, not main", dir, br))
		return false
	}
	old, _ := s.e.StdoutOf(dir, "git", "rev-parse", "--short", "HEAD")
	out, err := s.e.Output(dir, "git", "pull", "-q", "--ff-only", "origin", "main")
	if !s.step(label, err, out) {
		return false
	}
	if cur, _ := s.e.StdoutOf(dir, "git", "rev-parse", "--short", "HEAD"); cur != old {
		s.changed = append(s.changed, fmt.Sprintf("dotfiles (%s -> %s)", old, cur))
	}
	return true
}

// rebuildSelf builds gs from the dotfiles clone (current main) and installs it
// as ~/.local/bin/gs. -trimpath and -buildvcs=false make the bytes depend only
// on the source and the toolchain, so an unchanged source changes nothing.
func (s *syncRun) rebuildSelf() {
	const label = "gs (self)"
	stage, err := os.MkdirTemp(s.e.StateDir(), "build-")
	if err != nil {
		s.step(label, err, "")
		return
	}
	defer os.RemoveAll(stage)
	built := filepath.Join(stage, "gs")
	out, err := s.e.Output(filepath.Join(s.e.DotfilesDir(), "gs"), "go", "build", "-trimpath", "-buildvcs=false", "-o", built, ".")
	if !s.step(label, err, out) {
		return
	}
	changed, err := installAtomic(built, s.e.Target("gs"))
	if err != nil {
		s.step("gs (self) install", err, "")
		return
	}
	if changed {
		s.changed = append(s.changed, "gs (rebuilt)")
	}
}

// MacAppRepos are synced on consumer hosts when their clean clone exists.
var MacAppRepos = []string{"gentle-dot", "gentle-shell-desktop"}

func (s *syncRun) syncAppRepos() {
	for _, repo := range MacAppRepos {
		dir := filepath.Join(s.e.Clones(), repo)
		if !isDir(filepath.Join(dir, ".git")) {
			continue
		}
		label := repo
		if st, _ := s.e.StdoutOf(dir, "git", "status", "--porcelain"); st != "" {
			s.skip(label, repo+" has local changes")
			continue
		}
		s.e.Output(dir, "git", "checkout", "-q", "main")
		out, err := s.e.Output(dir, "git", "pull", "-q", "--ff-only", "--tags", "origin", "main")
		s.step(label, err, out)
	}
}

// upgradeShell runs `gentle-shell upgrade --channel main` only when the shell
// is behind GitHub main. The upgrade asks the GitHub API without a token (60
// requests/hour per IP), so it must not run when there is nothing to do.
func (s *syncRun) upgradeShell(version string) {
	const label = "gentle-shell upgrade (main)"
	built := mainBuildSHA(version)
	if remote := s.shellMain(); built != "" && remote != "" && strings.HasPrefix(remote, built) {
		s.skip(label, "already at main "+built)
		return
	}
	out, err := s.e.Output("", "gentle-shell", "upgrade", "--channel", "main")
	if err != nil && strings.Contains(out, "HTTP 403") {
		out += "\n(gentle-shell queries GitHub without a token: unauthenticated rate limit; gs sync again later)"
	}
	s.step(label, err, out)
}

func (s *syncRun) shellMain() string {
	sha, err := s.e.StdoutOf("", "gh", "api", "repos/"+Org+"/gentle-pi/commits/main", "--jq", ".sha")
	if err != nil {
		return ""
	}
	return sha
}

// mainBuildSHA extracts <sha> from a main-channel version x.y.z-main.<sha>.
func mainBuildSHA(version string) string {
	if i := strings.LastIndex(version, "-main."); i >= 0 {
		return version[i+len("-main."):]
	}
	return ""
}

// checkShellFresh compares the main-channel build SHA with GitHub main (gh).
func (s *syncRun) checkShellFresh(version string) {
	built := mainBuildSHA(version)
	if built == "" {
		s.failed = append(s.failed, fmt.Sprintf("gentle-shell %q is not a main-channel build", version))
		return
	}
	remote := s.shellMain()
	if remote == "" {
		fmt.Fprintln(s.e.Stdout, "WARN: could not read gentle-pi main through gh; freshness unverified")
		return
	}
	if !strings.HasPrefix(remote, built) {
		s.failed = append(s.failed, fmt.Sprintf("gentle-shell behind main (built %s, main %s)", built, short(remote)))
	}
}

// versions reads installed versions for the before/after summary.
func versions(e *Env) map[string]string {
	v := map[string]string{}
	if out, err := e.StdoutOf("", "gentle-shell", "--version"); err == nil {
		v["gentle-shell"] = field(firstLine(out), 1)
	}
	if out, err := e.StdoutOf("", e.Target("gentle-ai"), "--version"); err == nil {
		v["gentle-ai"] = field(firstLine(out), 1)
	}
	if out, err := e.StdoutOf("", e.Target("engram"), "version"); err == nil {
		v["engram"] = field(firstLine(out), 1)
	}
	return v
}

func field(s string, i int) string {
	f := strings.Fields(s)
	if i < len(f) {
		return f[i]
	}
	return ""
}

func short(sha string) string {
	if len(sha) > 12 {
		return sha[:12]
	}
	return sha
}

func orQ(s string) string {
	if s == "" {
		return "?"
	}
	return s
}

func isDir(p string) bool {
	fi, err := os.Stat(p)
	return err == nil && fi.IsDir()
}
