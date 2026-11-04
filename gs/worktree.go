package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
)

// repoName maps a short or full repo name to its GitHub name.
func repoName(arg string) (string, error) {
	switch arg {
	case "ai", "gentle-ai":
		return "gentle-ai", nil
	case "shell", "gentle-shell":
		return "gentle-shell", nil
	case "engram":
		return "engram", nil
	case "dot", "gentle-dot":
		return "gentle-dot", nil
	case "desktop", "gentle-shell-desktop":
		return "gentle-shell-desktop", nil
	}
	return "", failf("unknown repo '%s' (use: ai, shell, engram, dot, desktop)", arg)
}

// repoHere is the repo of the current directory's origin.
func repoHere(e *Env) (string, error) {
	url, err := e.StdoutOf("", "git", "remote", "get-url", "origin")
	if err != nil {
		return "", failf("give the repo (ai, shell, engram) or run it inside one")
	}
	base := strings.TrimSuffix(filepath.Base(url), ".git")
	switch base {
	case "gentle-ai", "gentle-shell", "engram", "gentle-dot", "gentle-shell-desktop":
		return base, nil
	case "gentle-pi":
		return "gentle-shell", nil
	}
	return "", failf("cannot tell the repo from %s; give it: ai, shell, engram, dot, desktop", url)
}

func cloneOf(e *Env, repo string) (string, error) {
	dir := filepath.Join(e.Clones(), repo)
	if !isDir(filepath.Join(dir, ".git")) {
		return "", failf("missing clean clone %s", dir)
	}
	if out, err := e.Output(dir, "git", "fetch", "-q", "--prune", "origin"); err != nil {
		return "", failf("git fetch in %s failed: %s", dir, out)
	}
	return dir, nil
}

func installDeps(e *Env, path string) error {
	if _, err := os.Stat(filepath.Join(path, "pnpm-lock.yaml")); err != nil {
		return nil
	}
	return e.Run(path, "pnpm", "install", "--frozen-lockfile")
}

func finish(e *Env, path string) {
	fmt.Fprintf(e.Stdout, "\nready: %s\n  cd %s\n", path, path)
}

func gitRun(e *Env, dir string, args ...string) error {
	if out, err := e.Output(dir, "git", args...); err != nil {
		return failf("git %s: %s", strings.Join(args, " "), out)
	}
	return nil
}

// herdrRename labels the Herdr workspace, tab and pane "<repo> - pr/is #<n>".
// Best-effort and silent: gs never fails because Herdr is absent.
func herdrRename(e *Env, label string) {
	if os.Getenv("HERDR_ENV") != "1" {
		return
	}
	if _, err := exec.LookPath("herdr"); err != nil {
		return
	}
	e.Output("", "herdr", "workspace", "rename", os.Getenv("HERDR_WORKSPACE_ID"), label)
	e.Output("", "herdr", "tab", "rename", os.Getenv("HERDR_TAB_ID"), label)
	e.Output("", "herdr", "pane", "rename", os.Getenv("HERDR_PANE_ID"), label)
}

// herdrTabRepo labels only the tab with the current repo name.
func herdrTabRepo(e *Env) {
	if os.Getenv("HERDR_ENV") != "1" {
		return
	}
	if _, err := exec.LookPath("herdr"); err != nil {
		return
	}
	url, err := e.StdoutOf("", "git", "remote", "get-url", "origin")
	if err != nil {
		return
	}
	e.Output("", "herdr", "tab", "rename", os.Getenv("HERDR_TAB_ID"), strings.TrimSuffix(filepath.Base(url), ".git"))
}

func cmdNew(e *Env, args []string) error {
	if len(args) != 2 {
		return failf("usage: gs new <repo> <name>")
	}
	repo, err := repoName(args[0])
	if err != nil {
		return err
	}
	clone, err := cloneOf(e, repo)
	if err != nil {
		return err
	}
	path := filepath.Join(e.Trees(), repo+"-"+args[1])
	if exists(path) {
		return failf("%s already exists", path)
	}
	if err := gitRun(e, clone, "worktree", "add", "-q", "-b", args[1], path, "origin/main"); err != nil {
		return err
	}
	herdrRename(e, repo+" - "+args[1])
	if err := installDeps(e, path); err != nil {
		return err
	}
	finish(e, path)
	return nil
}

func cmdReview(e *Env, args []string) error {
	if len(args) != 2 {
		return failf("usage: gs review <repo> <pr-number>")
	}
	repo, err := repoName(args[0])
	if err != nil {
		return err
	}
	if err := reviewWorktree(e, repo, args[1]); err != nil {
		return err
	}
	finish(e, filepath.Join(e.Trees(), repo+"-pr-"+args[1]))
	return nil
}

func reviewWorktree(e *Env, repo, num string) error {
	clone, err := cloneOf(e, repo)
	if err != nil {
		return err
	}
	path := filepath.Join(e.Trees(), repo+"-pr-"+num)
	if exists(path) {
		return failf("%s already exists (gs done inside it first)", path)
	}
	if err := gitRun(e, clone, "worktree", "add", "-q", "--detach", path, "origin/main"); err != nil {
		return err
	}
	if err := e.Run(path, "gh", "pr", "checkout", num, "-R", Org+"/"+repo, "-b", "pr-"+num); err != nil {
		return failf("gh pr checkout %s failed", num)
	}
	herdrRename(e, repo+" - pr #"+num)
	return installDeps(e, path)
}

// repoAndNumber parses "[repo] <n>".
func repoAndNumber(e *Env, cmd string, args []string) (string, string, error) {
	var repo, num string
	var err error
	switch len(args) {
	case 1:
		repo, err = repoHere(e)
		num = args[0]
	case 2:
		repo, err = repoName(args[0])
		num = args[1]
	default:
		return "", "", failf("usage: gs %s [repo] <number>", cmd)
	}
	if err != nil {
		return "", "", err
	}
	if _, err := strconv.ParseUint(num, 10, 64); err != nil {
		return "", "", failf("'%s' is not a number", num)
	}
	return repo, num, nil
}

func prPrompt(repo, num string) string {
	// The cortex variant of the skill is mandatory.
	return fmt.Sprintf("Review %s/%s PR #%s using the cortex-maintainer-delivery skill, loading it first (never the plain maintainer-delivery skill): read the PR, its linked issue, CI status and diff; run its preflight and race check; then report scope, risks, and what to test in Spanish. Do not comment, push, or merge.", Org, repo, num)
}

func issuePrompt(repo, num, branch string) string {
	// Plan-first: the session presents the kickoff and STOPS until the user
	// approves the plan. The cortex variant of the skill is mandatory.
	return fmt.Sprintf("Take %s/%s issue #%s using the cortex-maintainer-delivery skill, loading it first (never the plain maintainer-delivery skill): run its preflight, read the issue and repo conventions, then present a kickoff plan (expected behavior, approach, out of scope, branch %s) in Spanish and STOP. Do not implement, edit files, or commit: implementation starts only after the user explicitly approves the plan. Claiming, commenting, pushing, and opening the PR stay mine.", Org, repo, num, branch)
}

// openOrFinish opens Pi on a gentle-shell worktree with a kickoff prompt;
// other repos print where to go and the prompt to paste.
func openOrFinish(e *Env, repo, path, prompt string) error {
	if repo == "gentle-shell" {
		if err := os.Chdir(path); err != nil {
			return err
		}
		return cmdRun(e, []string{prompt})
	}
	finish(e, path)
	fmt.Fprintf(e.Stdout, "  kickoff: %s\n", prompt)
	return nil
}

func cmdPr(e *Env, args []string) error {
	repo, num, err := repoAndNumber(e, "pr", args)
	if err != nil {
		return err
	}
	path := filepath.Join(e.Trees(), repo+"-pr-"+num)
	if exists(path) {
		if st, _ := e.StdoutOf(path, "git", "status", "--porcelain"); st != "" {
			return failf("%s has local changes; commit, drop, or gs done first", path)
		}
		if err := e.Run(path, "gh", "pr", "checkout", num, "-R", Org+"/"+repo, "-b", "pr-"+num); err != nil {
			return failf("gh pr checkout %s failed", num)
		}
		herdrRename(e, repo+" - pr #"+num)
		if err := installDeps(e, path); err != nil {
			return err
		}
	} else if err := reviewWorktree(e, repo, num); err != nil {
		return err
	}
	return openOrFinish(e, repo, path, prPrompt(repo, num))
}

var (
	titlePrefix = regexp.MustCompile(`^[A-Za-z]+( [a-z]+)?: *`)
	nonSlug     = regexp.MustCompile(`[^a-z0-9]+`)
)

// issueSlug turns an issue title into a branch slug of at most 40 chars.
func issueSlug(title string) string {
	s := strings.ToLower(titlePrefix.ReplaceAllString(title, ""))
	s = strings.Trim(nonSlug.ReplaceAllString(s, "-"), "-")
	if len(s) > 40 {
		s = s[:40]
	}
	s = strings.TrimRight(s, "-")
	if s == "" {
		return "issue"
	}
	return s
}

func branchPrefix(labels []string) string {
	for _, want := range []struct{ label, prefix string }{
		{"type:feature", "feat"}, {"type:docs", "docs"}, {"type:refactor", "refactor"}, {"type:chore", "chore"},
	} {
		for _, l := range labels {
			if l == want.label {
				return want.prefix
			}
		}
	}
	return "fix"
}

func cmdIssue(e *Env, args []string) error {
	repo, num, err := repoAndNumber(e, "issue", args)
	if err != nil {
		return err
	}
	ghRepo := Org + "/" + repo
	info, err := e.StdoutOf("", "gh", "issue", "view", num, "-R", ghRepo, "--json", "state,assignees,title,labels",
		"--jq", `[.state, ([.assignees[].login]|join(",")), .title, ([.labels[].name]|join(","))]|join("\u001f")`)
	if err != nil {
		return failf("cannot read %s#%s", ghRepo, num)
	}
	parts := strings.SplitN(info, "\x1f", 4)
	for len(parts) < 4 {
		parts = append(parts, "")
	}
	state, assignees, title, labels := parts[0], splitComma(parts[1]), parts[2], splitComma(parts[3])
	path := filepath.Join(e.Trees(), repo+"-issue-"+num)
	if exists(path) {
		fmt.Fprintf(e.Stderr, "gs: reusing %s\n", path)
		herdrRename(e, repo+" - is #"+num)
		branch, _ := e.StdoutOf(path, "git", "branch", "--show-current")
		return openOrFinish(e, repo, path, issuePrompt(repo, num, branch))
	}
	if os.Getenv("GS_FORCE") != "1" {
		if state != "OPEN" {
			return failf("%s#%s is %s (GS_FORCE=1 to continue)", ghRepo, num, state)
		}
		// Your own assignment is your claim, not a race: only others block.
		me, _ := e.StdoutOf("", "gh", "api", "user", "--jq", ".login")
		var others []string
		for _, a := range assignees {
			if a != me {
				others = append(others, a)
			}
		}
		if len(others) > 0 {
			return failf("%s#%s is assigned to %s (GS_FORCE=1 to continue)", ghRepo, num, strings.Join(others, ","))
		}
		prs, _ := e.StdoutOf("", "gh", "pr", "list", "-R", ghRepo, "--state", "all", "--search", num+" in:title,body",
			"--json", "number,state,title", "--jq", `.[] | "  #\(.number) \(.state) \(.title)"`)
		var open, closed []string
		for _, l := range strings.Split(prs, "\n") {
			switch {
			case strings.TrimSpace(l) == "":
			case regexp.MustCompile(`^ *#[0-9]+ OPEN `).MatchString(l):
				open = append(open, l)
			default:
				closed = append(closed, l)
			}
		}
		// Only open PRs mean someone may be working on it now; merged/closed
		// ones are history (long issues ship in slices).
		if len(open) > 0 {
			return failf("Open PRs may already work on #%s (GS_FORCE=1 to continue):\n%s", num, strings.Join(open, "\n"))
		}
		if len(closed) > 0 {
			fmt.Fprintf(e.Stderr, "gs: #%s already has merged or closed PRs:\n%s\n", num, strings.Join(closed, "\n"))
		}
	}
	branch := branchPrefix(labels) + "/" + num + "-" + issueSlug(title)
	if err := gitRun(e, filepath.Join(e.Clones(), repo), "worktree", "add", "-q", "-b", branch, path, "origin/main"); err != nil {
		return err
	}
	herdrRename(e, repo+" - is #"+num)
	if err := installDeps(e, path); err != nil {
		return err
	}
	fmt.Fprintf(e.Stderr, "gs: %s#%s %q on branch %s\n", ghRepo, num, title, branch)
	return openOrFinish(e, repo, path, issuePrompt(repo, num, branch))
}

func cmdBase(e *Env, args []string) error {
	if len(args) != 1 {
		return failf("usage: gs base <repo>")
	}
	repo, err := repoName(args[0])
	if err != nil {
		return err
	}
	clone, err := cloneOf(e, repo)
	if err != nil {
		return err
	}
	path := filepath.Join(e.Trees(), repo+"-base")
	if exists(path) {
		if st, _ := e.StdoutOf(path, "git", "status", "--porcelain"); st != "" {
			return failf("%s has local changes; base must stay clean", path)
		}
		if err := gitRun(e, path, "checkout", "-q", "--detach", "origin/main"); err != nil {
			return err
		}
	} else if err := gitRun(e, clone, "worktree", "add", "-q", "--detach", path, "origin/main"); err != nil {
		return err
	}
	if err := installDeps(e, path); err != nil {
		return err
	}
	finish(e, path)
	return nil
}

func cmdLs(e *Env) error {
	for _, repo := range append(append([]string{}, Repos...), MacAppRepos...) {
		dir := filepath.Join(e.Clones(), repo)
		if !isDir(filepath.Join(dir, ".git")) {
			continue
		}
		out, _ := e.StdoutOf(dir, "git", "worktree", "list")
		for _, l := range strings.Split(out, "\n") {
			if l != "" && !strings.HasPrefix(l, dir+" ") {
				fmt.Fprintln(e.Stdout, l)
			}
		}
	}
	return nil
}

func cmdDone(e *Env) error {
	root, err := e.StdoutOf("", "git", "rev-parse", "--show-toplevel")
	if err != nil {
		return failf("run it inside a worktree")
	}
	trees, _ := filepath.EvalSymlinks(e.Trees())
	if !strings.HasPrefix(root, e.Trees()+"/") && (trees == "" || !strings.HasPrefix(root, trees+"/")) {
		return failf("%s is not a gs worktree", root)
	}
	// Harness task records (odd/tasks/*) never ship; drop them if they are the only leftovers.
	st, _ := e.StdoutOf(root, "git", "status", "--porcelain", "--untracked-files=all")
	var other, untracked []string
	for _, l := range strings.Split(st, "\n") {
		switch {
		case l == "":
		case strings.HasPrefix(l, "?? odd/tasks/"):
			untracked = append(untracked, strings.TrimPrefix(l, "?? "))
		default:
			other = append(other, l)
		}
	}
	if len(other) > 0 {
		return failf("uncommitted changes in %s:\n%s", root, strings.Join(other, "\n"))
	}
	for _, f := range untracked {
		os.RemoveAll(filepath.Join(root, f))
	}
	if err := gitRun(e, root, "fetch", "-q", "--prune", "origin"); err != nil {
		return err
	}
	if local, _ := e.StdoutOf(root, "git", "log", "--oneline", "HEAD", "--not", "--remotes"); local != "" {
		head, _ := e.StdoutOf(root, "git", "rev-parse", "HEAD")
		refs, _ := e.StdoutOf(root, "git", "ls-remote", "origin", "refs/pull/*/head")
		if head == "" || !strings.Contains(refs, head) {
			return failf("commits not on any remote in %s; push or drop them yourself first", root)
		}
	}
	list, _ := e.StdoutOf(root, "git", "worktree", "list", "--porcelain")
	main := strings.TrimPrefix(strings.SplitN(list, "\n", 2)[0], "worktree ")
	branch, _ := e.StdoutOf(root, "git", "branch", "--show-current")
	if err := gitRun(e, main, "worktree", "remove", root); err != nil {
		return err
	}
	fmt.Fprintf(e.Stdout, "removed %s\n", root)
	if branch != "" {
		_, ancErr := e.Output(main, "git", "merge-base", "--is-ancestor", branch, "origin/main")
		if ancErr == nil && gitRun(e, main, "branch", "-D", branch) == nil {
			fmt.Fprintf(e.Stdout, "deleted local branch %s (already in origin/main)\n", branch)
		} else {
			fmt.Fprintf(e.Stdout, "kept local branch %s (not fully in main; delete it yourself if the PR was squash-merged)\n", branch)
		}
	}
	fmt.Fprintf(e.Stdout, "now run: cd %s\n", main)
	return nil
}

// isShellCheckout reports whether root is a gentle-shell (gentle-pi) package.
func isShellCheckout(root string) bool {
	b, err := os.ReadFile(filepath.Join(root, "package.json"))
	return err == nil && regexp.MustCompile(`"name": *"gentle-pi"`).Match(b)
}

// cmdRun runs gentle-shell --isolated with this worktree as --package-root.
func cmdRun(e *Env, args []string) error {
	root, err := e.StdoutOf("", "git", "rev-parse", "--show-toplevel")
	if err != nil {
		return failf("run it inside a gentle-shell worktree")
	}
	if !isShellCheckout(root) {
		return failf("%s is not gentle-shell", root)
	}
	if !isDir(filepath.Join(root, "node_modules")) {
		return failf("no node_modules in %s (pnpm install --frozen-lockfile)", root)
	}
	head, _ := e.StdoutOf(root, "git", "rev-parse", "--short", "HEAD")
	fmt.Fprintf(e.Stderr, "gs: gentle-shell @ %s (%s); subagents use main\n", head, root)
	return execIn(e, root, "node", append([]string{filepath.Join(root, "bin", "gentle-shell.mjs"), "--isolated", "--package-root", root}, args...))
}

// cmdLaunch is plain `gs [args]`.
// Workshop: inside a gentle-shell checkout Pi loads that path (gs run);
// elsewhere the synced clone, isolated. Consumer: the official gentle-shell on
// PATH with the arguments unchanged.
func cmdLaunch(e *Env, args []string) error {
	ws := isWorkshop(e)
	if ws {
		if here, err := e.StdoutOf("", "git", "rev-parse", "--show-toplevel"); err == nil && isShellCheckout(here) {
			herdrTabRepo(e)
			return cmdRun(e, args)
		}
		root := filepath.Join(e.Clones(), "gentle-shell")
		if _, err := os.Stat(filepath.Join(root, "bin", "gentle-shell.mjs")); err != nil {
			return failf("gentle-shell not found at %s (run: gs sync)", root)
		}
		herdrTabRepo(e)
		return execIn(e, "", "node", append([]string{filepath.Join(root, "bin", "gentle-shell.mjs"), "--isolated"}, args...))
	}
	if _, err := exec.LookPath("gentle-shell"); err != nil {
		return failf("gentle-shell not on PATH (install it, then run: gs sync)")
	}
	herdrTabRepo(e)
	return execIn(e, "", "gentle-shell", args)
}

// execIn replaces gs with the command (exit status and signals pass through).
// ExecHook lets tests observe it instead.
var ExecHook func(dir, name string, args []string) error

func execIn(e *Env, dir, name string, args []string) error {
	if ExecHook != nil {
		return ExecHook(dir, name, args)
	}
	path, err := exec.LookPath(name)
	if err != nil {
		return failf("%s not found on PATH", name)
	}
	if dir != "" {
		if err := os.Chdir(dir); err != nil {
			return err
		}
	}
	return syscall.Exec(path, append([]string{name}, args...), e.environ())
}

func exists(p string) bool {
	_, err := os.Lstat(p)
	return err == nil
}

func splitComma(s string) []string {
	if s == "" {
		return nil
	}
	return strings.Split(s, ",")
}
