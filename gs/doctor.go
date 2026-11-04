package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"syscall"
)

// report collects ok/WARN/FAIL lines; any FAIL makes the command exit 1.
type report struct {
	env   *Env
	fails []string
}

func (r *report) ok(name, detail string)   { r.line("ok  ", name, detail) }
func (r *report) warn(name, detail string) { r.line("WARN", name, detail) }
func (r *report) fail(name, detail string) {
	r.fails = append(r.fails, name)
	r.line("FAIL", name, detail)
}

func (r *report) line(status, name, detail string) {
	if detail == "" {
		fmt.Fprintf(r.env.Stdout, "%s %s\n", status, name)
		return
	}
	fmt.Fprintf(r.env.Stdout, "%s %s: %s\n", status, name, detail)
}

func (r *report) err(what string) error {
	if len(r.fails) == 0 {
		return nil
	}
	return failf("%s: %d check(s) failed: %s", what, len(r.fails), strings.Join(r.fails, ", "))
}

// cmdDoctor reports every piece of this host that differs from what gs installs.
// It changes nothing.
func cmdDoctor(e *Env) error {
	r := &report{env: e}
	checkHost(e, r)
	return r.err("gs doctor")
}

// checkHost is shared by gs doctor and the final verification of gs sync.
func checkHost(e *Env, r *report) {
	for _, b := range Managed {
		checkManaged(e, r, b.Name)
	}
	if out, err := e.Output("", e.Target("engram"), "instance-id"); err != nil {
		r.fail("engram instance-id", "fails (Engram older than v2.0.0-rc.11): "+firstLine(out))
	} else {
		r.ok("engram instance-id", "")
	}
	if out, err := e.Output("", "gh", "auth", "status"); err != nil {
		r.fail("gh auth", "gh is not authenticated: "+firstLine(out))
	} else {
		r.ok("gh auth", "")
	}
	if p, err := exec.LookPath("gentle-shell"); err != nil {
		r.fail("gentle-shell", "not on PATH")
	} else {
		v, _ := e.StdoutOf("", p, "--version")
		r.ok("gentle-shell", firstLine(v))
	}
	if gobin, _ := e.StdoutOf("", "go", "env", "GOBIN"); samePath(gobin, e.BinDir()) {
		r.warn("go env GOBIN", gobin+": any `go install` replaces gs-managed binaries; run: go env -u GOBIN")
	}
	for _, b := range Managed {
		for _, p := range strayCopies(e, b.Name) {
			r.warn("stray copy "+p, "not used by gs; remove it")
		}
	}
	if entries, _ := os.ReadDir(e.Quarantine()); len(entries) > 0 {
		names := make([]string, 0, len(entries))
		for _, en := range entries {
			names = append(names, en.Name())
		}
		r.warn("quarantine", "a sync step tried to install "+strings.Join(names, ", ")+" ("+e.Quarantine()+")")
	}
	for _, p := range staleEngramProcesses(e) {
		r.warn("engram process "+p, "runs an old binary; restart it (gs sync restarts the service; agents: /mcp reconnect)")
	}
}

// checkManaged requires PATH to resolve name to our regular file in BinDir.
func checkManaged(e *Env, r *report, name string) {
	target := e.Target(name)
	fi, err := os.Lstat(target)
	switch {
	case err != nil:
		r.fail(name, target+" is missing (run: gs sync)")
		return
	case fi.Mode()&os.ModeSymlink != 0:
		dest, _ := os.Readlink(target)
		r.fail(name, target+" is a symlink to "+dest+"; gs installs regular files (run: gs sync)")
		return
	case !fi.Mode().IsRegular() || fi.Mode()&0o111 == 0:
		r.fail(name, target+" is not an executable file")
		return
	}
	if p, err := exec.LookPath(name); err != nil || !samePath(p, target) {
		r.fail(name+" on PATH", fmt.Sprintf("resolves to %q, not %s", p, target))
		return
	}
	v, _ := e.StdoutOf("", target, "version")
	r.ok(name, firstLine(v))
}

// strayCopies are other builds of a managed binary that could shadow it later.
func strayCopies(e *Env, name string) []string {
	var out []string
	for _, p := range []string{
		filepath.Join(e.Home, "go", "bin", name),
		e.Target(name) + ".pre-gw",
	} {
		if _, err := os.Lstat(p); err == nil {
			out = append(out, p)
		}
	}
	return out
}

// staleEngramProcesses lists running engram processes whose executable is not
// the current ~/.local/bin/engram (deleted or replaced since they started).
func staleEngramProcesses(e *Env) []string {
	pids, err := e.StdoutOf("", "pgrep", "-f", "engram (serve|mcp)")
	if err != nil || pids == "" {
		return nil
	}
	want, err := inode(e.Target("engram"))
	if err != nil {
		return nil
	}
	var stale []string
	for _, pid := range strings.Fields(pids) {
		if _, err := strconv.Atoi(pid); err != nil {
			continue
		}
		got, ok := processInode(e, pid)
		if ok && got != want {
			stale = append(stale, pid)
		}
	}
	return stale
}

func processInode(e *Env, pid string) (uint64, bool) {
	if runtime.GOOS == "linux" {
		link, err := os.Readlink("/proc/" + pid + "/exe")
		if err != nil {
			return 0, false
		}
		if strings.HasSuffix(link, " (deleted)") {
			return 0, true
		}
		ino, err := inode(link)
		return ino, err == nil
	}
	out, err := e.StdoutOf("", "lsof", "-a", "-p", pid, "-d", "txt", "-Fi")
	if err != nil {
		return 0, false
	}
	for _, l := range strings.Split(out, "\n") {
		if strings.HasPrefix(l, "i") {
			n, err := strconv.ParseUint(l[1:], 10, 64)
			return n, err == nil
		}
	}
	return 0, false
}

func inode(path string) (uint64, error) {
	fi, err := os.Stat(path)
	if err != nil {
		return 0, err
	}
	st, ok := fi.Sys().(*syscall.Stat_t)
	if !ok {
		return 0, fmt.Errorf("no inode for %s", path)
	}
	return uint64(st.Ino), nil
}

func samePath(a, b string) bool {
	if a == "" || b == "" {
		return false
	}
	ra, err1 := filepath.EvalSymlinks(filepath.Dir(a))
	rb, err2 := filepath.EvalSymlinks(filepath.Dir(b))
	if err1 != nil || err2 != nil {
		return filepath.Clean(a) == filepath.Clean(b)
	}
	return filepath.Join(ra, filepath.Base(a)) == filepath.Join(rb, filepath.Base(b))
}

func firstLine(s string) string {
	s = strings.TrimSpace(s)
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return s[:i]
	}
	return s
}
