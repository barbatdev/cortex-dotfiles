# gs-official: official Gentle Shell launcher (agent-dev only)

`bin/gs-official` is deployed as `gs` on the migrated agent-dev host only. It launches the official `gentle-shell` and keeps Gentle Shell and the external Gentle AI on `main`.

> The legacy `bin/gs` (Mac and workshop) is unchanged and is not replaced by this script.

## Quick path

| Command | What it does |
|---------|--------------|
| `gs [args...]` | Runs `gentle-shell "$@"` via `exec`. Arguments and exit status pass through unchanged. No `--link` or `--package-root` is added. |
| `gs sync` | Updates both tools from `main`, then syncs Claude Code assets. Takes no arguments. |
| `gs help` | Shows usage (`-h` and `--help` also work). |

## What `gs sync` runs

Steps run in order and stop at the first failure. The failing command's output is shown, and `gs` exits with that command's exit status. There is no fallback to the stable channel.

1. Preflight. Nothing changes until every check passes:
   - `gentle-shell` and `go` are on `PATH`.
   - `gentle-ai` resolves to `~/.local/bin/gentle-ai`.
   - That file is a regular executable, not a symlink, and the current user owns it.
   - `~/.local/bin` is writable.
2. `gentle-shell upgrade --channel main`
3. `GOBIN=~/.local/bin go install github.com/gentleman-programming/gentle-ai/v4/cmd/gentle-ai@main`
4. `~/.local/bin/gentle-ai sync --agents claude-code` (Claude Code only)
5. Version report: `gentle-shell --version`, `gentle-ai version`, `go version -m ~/.local/bin/gentle-ai`

## Details

- **Main is not a persistent channel.** `go install ...@main` builds the current `main` once. It does not pin anything for later, so each `gs sync` installs `@main` again.
- **Identifying the installed commit.** A build from source may report its version as `dev` or as a pseudo-version. Use the `go version -m` output (the module pseudo-version and `vcs.revision`, when present) to confirm which `main` commit is installed. Do not read a semantic version number as proof that you are on `main`.
- **Fail-closed target.** If `gentle-ai` resolves anywhere other than `~/.local/bin` (for example, a package-managed copy or a symlink), `gs sync` refuses to run. This keeps it from updating a different copy than the one on your `PATH`.
- **Out of scope.** No Engram updates, no pi self-update, no dotfiles pulls, and no custom clones. Credentials, memories, and conversations are never touched.
- **PATH setup.** Putting `~/.local/bin` and the deployed `gs` on `PATH` for fresh zsh sessions is handled by a separate agent-dev drop-in, not by the shared zsh profile.

## Tests

```bash
python3 -m unittest discover -s tests -p gs_official_test.py
```

The tests use a temporary `HOME` and `PATH` shims. They make no network calls and do not touch real binaries.
