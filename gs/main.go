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
	cmd := ""
	if len(args) > 0 {
		cmd = args[0]
	}
	switch cmd {
	case "sync":
		return cmdSync(e)
	case "doctor":
		return cmdDoctor(e)
	case "help", "-h", "--help":
		fmt.Fprint(e.Stdout, usage)
		return nil
	}
	return failf("unknown command %q (gs help)", cmd)
}

const usage = `gs - gentle-shell on main, plus one disposable worktree per PR

  gs doctor                Report everything on this host that differs from
                           what gs installs; changes nothing
  gs help                  Show this help
`
