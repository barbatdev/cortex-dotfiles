package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type execCall struct {
	dir, name string
	args      []string
}

func captureExec(t *testing.T) *[]execCall {
	var calls []execCall
	ExecHook = func(dir, name string, args []string) error {
		calls = append(calls, execCall{dir, name, args})
		return nil
	}
	t.Cleanup(func() { ExecHook = nil })
	return &calls
}

func chdir(t *testing.T, dir string) {
	t.Helper()
	old, _ := os.Getwd()
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chdir(old) })
}

// shellCheckout makes dir a gentle-shell package with node_modules.
func shellCheckout(t *testing.T, dir string) {
	os.MkdirAll(filepath.Join(dir, "bin"), 0o755)
	os.MkdirAll(filepath.Join(dir, "node_modules"), 0o755)
	os.WriteFile(filepath.Join(dir, "package.json"), []byte(`{"name": "gentle-pi"}`), 0o644)
	os.WriteFile(filepath.Join(dir, "bin", "gentle-shell.mjs"), []byte(""), 0o755)
}

func TestConsumerLaunchExecsGentleShellWithArgsUnchanged(t *testing.T) {
	s := newSandbox(t)
	s.healthy()
	calls := captureExec(t)
	chdir(t, s.home)
	if err := dispatch(s.env, []string{"-c", "x"}); err != nil {
		t.Fatal(err)
	}
	if len(*calls) != 1 || (*calls)[0].name != "gentle-shell" || strings.Join((*calls)[0].args, " ") != "-c x" {
		t.Fatalf("want exec gentle-shell -c x, got %+v", *calls)
	}
}

func TestConsumerLaunchWithoutGentleShellFails(t *testing.T) {
	s := newSandbox(t)
	captureExec(t)
	chdir(t, s.home)
	err := dispatch(s.env, nil)
	if err == nil || !strings.Contains(err.Error(), "gentle-shell not on PATH") {
		t.Fatalf("want not-on-PATH failure, got %v", err)
	}
}

func TestWorkshopLaunchOpensCloneIsolated(t *testing.T) {
	s := workshopHost(t)
	shellCheckout(t, filepath.Join(s.env.Clones(), "gentle-shell"))
	calls := captureExec(t)
	chdir(t, s.home)
	if err := dispatch(s.env, []string{"--model", "m"}); err != nil {
		t.Fatal(err)
	}
	c := (*calls)[0]
	want := filepath.Join(s.env.Clones(), "gentle-shell", "bin", "gentle-shell.mjs") + " --isolated --model m"
	if c.name != "node" || strings.Join(c.args, " ") != want {
		t.Fatalf("want node %s, got %+v", want, c)
	}
}

func TestWorkshopLaunchInsideShellWorktreeLoadsThatPath(t *testing.T) {
	s := workshopHost(t)
	wt := filepath.Join(s.env.Trees(), "gentle-shell-pr-7")
	os.MkdirAll(wt, 0o755)
	git(t, wt, "init", "-q")
	shellCheckout(t, wt)
	calls := captureExec(t)
	chdir(t, wt)
	if err := dispatch(s.env, nil); err != nil {
		t.Fatal(err)
	}
	args := strings.Join((*calls)[0].args, " ")
	contains(t, args, "--isolated --package-root ")
	contains(t, args, "gentle-shell-pr-7")
	notContains(t, args, "--link")
}

func TestRunOutsideShellCheckoutFails(t *testing.T) {
	s := newSandbox(t)
	captureExec(t)
	dir := filepath.Join(s.home, "other")
	os.MkdirAll(dir, 0o755)
	git(t, dir, "init", "-q")
	chdir(t, dir)
	err := cmdRun(s.env, nil)
	if err == nil || !strings.Contains(err.Error(), "is not gentle-shell") {
		t.Fatalf("want not-gentle-shell failure, got %v", err)
	}
}

func TestIssueSlugAndPrefix(t *testing.T) {
	cases := map[string]string{
		"fix: Engram v1 replaces the binary!":                          "engram-v1-replaces-the-binary",
		"fix(gs): keeps scope":                                         "fix-gs-keeps-scope",
		"feat: a very long title that goes on and on past forty chars": "a-very-long-title-that-goes-on-and-on-pa",
		"???": "issue",
	}
	for in, want := range cases {
		if got := issueSlug(in); got != want {
			t.Errorf("issueSlug(%q) = %q, want %q", in, got, want)
		}
	}
	if branchPrefix([]string{"bug", "type:docs"}) != "docs" || branchPrefix(nil) != "fix" {
		t.Error("branch prefix from labels")
	}
}

// issueHost is a workshop host whose gh answers issue 9 with the given fields.
func issueHost(t *testing.T, assignees, prs string) *sandbox {
	s := workshopHost(t)
	s.stub("gh", `case "$1 $2" in
  "auth status") exit 0 ;;
  "auth token") echo tok ;;
  "issue view") printf 'OPEN\037`+assignees+`\037fix: slow sync\037type:feature\n' ;;
  "api user") echo me ;;
  "pr list") printf '`+prs+`' ;;
esac`)
	captureExec(t)
	return s
}

func TestIssueAssignedOnlyToYouPasses(t *testing.T) {
	s := issueHost(t, "me", "")
	if err := cmdIssue(s.env, []string{"ai", "9"}); err != nil {
		t.Fatalf("own assignment must pass: %v", err)
	}
	contains(t, s.out.String(), "feat/9-slow-sync")
	contains(t, s.out.String(), "kickoff: Take Gentleman-Programming/gentle-ai issue #9 using the cortex-maintainer-delivery skill")
}

func TestIssueAssignedToOthersStopsAndNamesOnlyThem(t *testing.T) {
	s := issueHost(t, "me,ana", "")
	err := cmdIssue(s.env, []string{"ai", "9"})
	if err == nil || !strings.Contains(err.Error(), "is assigned to ana (GS_FORCE=1 to continue)") {
		t.Fatalf("want assigned-to-ana failure, got %v", err)
	}
}

func TestIssueWithOpenPRStopsAndClosedPRsOnlyWarn(t *testing.T) {
	s := issueHost(t, "", `  #5 MERGED feat: slice one (#9)\n  #7 OPEN feat: slice two (#9)\n`)
	err := cmdIssue(s.env, []string{"ai", "9"})
	if err == nil || !strings.Contains(err.Error(), "#7 OPEN feat: slice two (#9)") || strings.Contains(err.Error(), "#5 MERGED") {
		t.Fatalf("want open-PR failure naming only #7, got %v", err)
	}
	s = issueHost(t, "", `  #5 MERGED feat: slice one (#9)\n`)
	if err := cmdIssue(s.env, []string{"ai", "9"}); err != nil {
		t.Fatalf("only merged PRs must continue: %v", err)
	}
	contains(t, s.out.String(), "already has merged or closed PRs")
}

func TestPrPromptNamesCortexSkill(t *testing.T) {
	p := prPrompt("gentle-shell", "3")
	contains(t, p, "cortex-maintainer-delivery skill")
	notContains(t, p, ".pi/agent")
}

func TestDoneRefusesUncommittedWork(t *testing.T) {
	s := workshopHost(t)
	clone := filepath.Join(s.env.Clones(), "gentle-ai")
	wt := filepath.Join(s.env.Trees(), "gentle-ai-x")
	git(t, clone, "worktree", "add", "-q", "-b", "x", wt, "origin/main")
	os.WriteFile(filepath.Join(wt, "work.go"), []byte("x"), 0o644)
	os.MkdirAll(filepath.Join(wt, "odd", "tasks"), 0o755)
	os.WriteFile(filepath.Join(wt, "odd", "tasks", "t.md"), []byte("x"), 0o644)
	chdir(t, wt)
	err := cmdDone(s.env)
	if err == nil || !strings.Contains(err.Error(), "work.go") {
		t.Fatalf("want refusal naming work.go, got %v", err)
	}
	if !exists(wt) {
		t.Fatal("worktree must survive a refusal")
	}
}

func TestDoneRemovesMergedWorktreeAndDropsTaskRecords(t *testing.T) {
	s := workshopHost(t)
	clone := filepath.Join(s.env.Clones(), "gentle-ai")
	wt := filepath.Join(s.env.Trees(), "gentle-ai-y")
	git(t, clone, "worktree", "add", "-q", "-b", "y", wt, "origin/main")
	os.MkdirAll(filepath.Join(wt, "odd", "tasks"), 0o755)
	os.WriteFile(filepath.Join(wt, "odd", "tasks", "t.md"), []byte("x"), 0o644)
	chdir(t, wt)
	if err := cmdDone(s.env); err != nil {
		t.Fatalf("done failed: %v\n%s", err, s.out.String())
	}
	if exists(wt) {
		t.Fatal("worktree must be removed")
	}
	contains(t, s.out.String(), "deleted local branch y (already in origin/main)")
}
