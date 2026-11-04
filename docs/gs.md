# gs

`gs` is one Go binary (source: [`gs/`](../gs)) that behaves the same on every host. It replaces the former `bin/gs` and `bin/gs-official` scripts.

## Install

`./install.sh` builds it into `~/.local/bin/gs`. After that, `gs sync` rebuilds it from the dotfiles clone, but only while that clone is clean and on `main`. A feature branch is never installed as `gs`.

```bash
cd gs && go build -trimpath -buildvcs=false -o ~/.local/bin/gs .   # manual build
```

## Hosts

| Host | Mode | Detected by |
|------|------|-------------|
| Mac, agent-dev | consumer | no clone at `~/dev/gentle/gentle-shell` |
| agent-gentle | workshop | `~/dev/gentle/gentle-shell` has origin `Gentleman-Programming/gentle-shell` |

Plain `gs [args]` runs the official `gentle-shell` with the arguments unchanged in consumer mode. In workshop mode it opens the clone with `--isolated`, or with `--package-root <root>` when run from inside a gentle-shell checkout (same as `gs run`).

## gs sync

1. Preflight: `gh auth status`, `gh auth token`, `go`, and in consumer mode `gentle-shell`. If any of these fails, nothing is changed.
2. Every later step runs with `GOBIN=~/.local/share/gs/quarantine`, `GH_TOKEN`/`GITHUB_TOKEN` from `gh`, `GENTLE_AI_ENGRAM_BIN=~/.local/bin/engram` and `GENTLE_SHELL_NO_AUTO_SETUP=1`. Any `go install` run by gentle-shell or gentle-ai lands in the quarantine dir and can never replace the binaries gs manages.
3. Sources:
   - Consumer: the main commit of `gentle-ai` and `engram`, resolved through `gh api`.
   - Workshop: clean clones in `~/dev/gentle`, fast-forwarded to `origin/main`.
4. Consumer only: `gentle-shell upgrade --channel main`, but only when the shell build is behind `gentle-pi` main. That upgrade asks GitHub without a token (unauthenticated rate limit), so it is skipped when there is nothing to do.
5. `gentle-ai` and `engram` are built from the pinned commit into a staging dir.
   - Before installing, the build must pass a check: `engram instance-id` for engram, and `version` for both.
   - Then the binary is installed in `~/.local/bin` as a regular file through an atomic rename. A symlink at that path is replaced, never followed.
6. Workshop only: `pnpm install` in gentle-shell, `npm install` in the engram Pi plugin, and registration of `~/.pi/gentle-ai/dev-binary.json` (mode 0600).
7. `gentle-ai sync --agents claude-code`. `GS_SYNC_AGENTS=a,b` changes the agents and `GS_SKIP_AI_SYNC=1` skips this step. Workshop then runs `gentle-shell --isolated setup`.
8. Restarts the Engram service (LaunchAgent `com.gentleman-programming.engram` or the systemd user unit `engram.service`) when Engram changed or a running engram uses an old binary. Agent MCP clients still need `/mcp` → reconnect.
9. Pulls the dotfiles clone (clean, on `main`; `GS_SKIP_DOTFILES=1` skips), rebuilds `gs` from it, and on consumer hosts pulls the clean `gentle-dot` and `gentle-shell-desktop` clones.
10. Runs the `gs doctor` checks. Any failure prints `INCOMPLETE — failed: …` and exits 1.

## gs doctor

`gs doctor` changes nothing. It fails when:

- `gentle-ai` or `engram` is missing in `~/.local/bin`, is a symlink, or is not the copy `PATH` resolves.
- `engram instance-id` fails (Engram older than v2.0.0-rc.11).
- `gh` is not authenticated.
- `gentle-shell` is not on `PATH`.

It warns about:

- `go env GOBIN` set to `~/.local/bin`.
- Stray copies (`~/go/bin/<name>`, `~/.local/bin/<name>.pre-gw`).
- Anything left in the quarantine dir.
- engram processes that still run an old binary.

## Worktree commands

These work the same as the former script: `gs pr`, `gs issue`, `gs new`, `gs review`, `gs base`, `gs run`, `gs ls`, `gs done`. Run `gs help` for the details. `gs done` now also drops untracked `odd/tasks/` records when the whole `odd/` directory is untracked.

## Tests

```bash
cd gs && go test ./...
```

The tests use a temporary `HOME` and shell stubs on `PATH` (`gh`, `go`, `gentle-shell`, `launchctl`, `systemctl`). They make no network calls and never touch real binaries or services.
