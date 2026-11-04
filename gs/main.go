// Command gs keeps gentle-shell, gentle-ai and Engram on main the same way on
// every host, and opens one disposable worktree per PR or issue.
// It never pushes, merges, force-deletes, or edits settings.
package main

import (
	"errors"
	"fmt"
	"os"
)

func main() {
	e := newEnv()
	if err := dispatch(e, os.Args[1:]); err != nil {
		var f Fail
		if errors.As(err, &f) {
			fmt.Fprintf(os.Stderr, "gs: %s\n", f)
		} else {
			fmt.Fprintf(os.Stderr, "gs: %v\n", err)
		}
		os.Exit(1)
	}
}

func dispatch(e *Env, args []string) error {
	cmd, rest := "", []string{}
	if len(args) > 0 {
		cmd, rest = args[0], args[1:]
	}
	switch cmd {
	case "sync":
		return cmdSync(e)
	case "doctor":
		return cmdDoctor(e)
	case "pr":
		return cmdPr(e, rest)
	case "issue":
		return cmdIssue(e, rest)
	case "new":
		return cmdNew(e, rest)
	case "review":
		return cmdReview(e, rest)
	case "base":
		return cmdBase(e, rest)
	case "run":
		return cmdRun(e, rest)
	case "ls":
		return cmdLs(e)
	case "done":
		return cmdDone(e)
	case "help", "-h", "--help":
		fmt.Fprint(e.Stdout, usage)
		return nil
	}
	return cmdLaunch(e, args)
}

const usage = `gs - gentle-shell on main, plus one disposable worktree per PR

  gs [args...]             Open gentle-shell. Consumer (Mac, agent-dev): the
                           official gentle-shell on PATH, arguments unchanged.
                           Workshop (agent-gentle): inside a gentle-shell clone or
                           worktree, Pi loads that path (gs run); elsewhere the
                           synced clone, --isolated.

  gs sync                  Bring gentle-shell, gentle-ai and engram to main the
                           same way on every host:
                           - gentle-ai and engram are built by gs from one pinned
                             commit (GitHub main through gh; workshop: the clean
                             clones in ~/dev/gentle), verified (engram instance-id)
                             and installed in ~/.local/bin as regular files
                           - every other step runs with GOBIN in a quarantine dir,
                             so no other installer can replace them
                           - gentle-shell upgrade runs only when behind main
                           - gentle-ai sync --agents claude-code (GS_SYNC_AGENTS=a,b
                             to change, GS_SKIP_AI_SYNC=1 to skip); workshop also
                             runs gentle-shell --isolated setup
                           - restarts the Engram service when Engram changed
                           - pulls the dotfiles clone (clean, on main only;
                             GS_SKIP_DOTFILES=1 skips)
                           Ends with the gs doctor checks; any failure prints
                           INCOMPLETE and exits 1.
  gs doctor                Report everything on this host that differs from what
                           gs installs; changes nothing

  gs pr [repo] <n>         Review PR <n>: worktree (reused and updated if it
                           exists), then Pi on it for shell PRs
  gs issue [repo] <n>      Start issue <n>: race check (stops if the issue is
                           closed, assigned to someone other than you, or
                           referenced by an open PR; GS_FORCE=1 skips it), branch
                           <type>/<n>-<slug> from origin/main, then Pi on it for
                           shell issues
  gs new <repo> <name>     New branch <name> from fresh origin/main
  gs review <repo> <pr>    Check out someone else's PR to test or review it
  gs base <repo>           Clean origin/main worktree, to compare failures
  gs run [pi args...]      Run gentle-shell --isolated with this worktree as --package-root
  gs ls                    List open worktrees
  gs done                  Remove the current worktree and its merged local branch
                           (drops odd/tasks records; refuses if real work would be lost)
  gs help                  Show this help

  <repo>: ai | shell | engram | dot | desktop   (or the full name)
  [repo] is optional inside a clone or worktree of that repo.
  GitHub access always goes through the authenticated gh.
  Never pushes, merges, force-deletes, or edits settings.
`
