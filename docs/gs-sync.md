# gs and gs sync: one gentle-shell install

`gs` launches exactly the gentle-shell package that `gs sync` updates and checks:

| Mode | Detected when | `gs sync` updates | `gs` launches |
|------|---------------|-------------------|---------------|
| workshop (agent-gentle) | `~/dev/gentle/gentle-shell` is a clone of Gentleman-Programming/gentle-shell | that clone (`git pull`, `pnpm install`) | inside a gentle-shell clone or worktree: that path (`--package-root`, like `gs run`); elsewhere: the synced clone |
| consumer (standard workstations) | anything else | `gentle-shell upgrade --channel main` | the package behind `gentle-shell` on PATH (symlinks resolved) |

The launcher loads its extensions and its bundled Pi from its own package root,
so the package it starts from decides what you see.

## Isolated home, never `--link`

Every launch (`gs`, `gs run`, and the Pi session opened by `gs pr` / `gs issue`)
passes `--isolated`, so Shell uses the official isolated home
`~/.gentle-shell/agent`; from a clone or worktree it also passes
`--package-root <root>`. `gs` never passes `--link` and never loads `~/.pi/agent`.

Workshop `gs sync` also stays off the legacy Pi home:

- It does not add `~/.pi/agent/bin` to PATH and does not run `pi update` or
  `pi update --extensions`; Shell runs the Pi bundled in the clone
  (`node_modules/@earendil-works/pi-coding-agent`).
- It registers Gentle AI main in `~/.pi/gentle-ai/dev-binary.json` (file
  `0600`, atomic write) with
  `{"schema":"gentle-pi.dev-binary/v1","path":"~/.local/share/gentle-ai/main/gentle-ai"}`.
  This path is install-level state: the official launcher reads it there even
  for the isolated home, so it is not moved to `~/.gentle-shell/gentle-ai`.
- It no longer warns about `gentle-pi`/`gentle-engram` in the isolated home's
  `settings.json`: the official Shell declares and requires them there, and the
  `--package-root` take-over loads the clone instead of the published gentle-pi.
- It runs `gentle-ai sync --agents claude-code` (Claude Code only; never the
  legacy `pi` agent nor `opencode`). `GS_SYNC_AGENTS=a,b` overrides the agents.
- It then runs `node ~/dev/gentle/gentle-shell/bin/gentle-shell.mjs --isolated setup`
  (`gentle-shell setup (isolated home)`), the official re-provisioning of
  `~/.gentle-shell/agent`. A failure marks the sync `INCOMPLETE` and shows its output.
- `GS_SKIP_AI_SYNC=1` skips both steps and prints a `skipped` line for each.

The `gs pr` / `gs issue` kickoff prompts name the `cortex-maintainer-delivery`
skill without a home path. Consumer sync keeps its official update steps
(`pi update`, `gentle-shell upgrade --channel main`, `pi update --extensions`)
and runs `gentle-ai sync` with `--agents` only when `GS_SYNC_AGENTS` is set.

## Why this changed

Before, consumer `gs` started
`~/.pi/agent/git/github.com/Gentleman-Programming/gentle-pi/bin/gentle-shell.mjs`.
That checkout came from an older setup in which Pi tracked `git:gentle-pi` in
`~/.pi/agent/settings.json`. Once that entry was removed, nothing updated the
checkout, while `gs sync` upgraded the global npm package behind `gentle-shell`.
Result: `gentle-shell --version` showed the new main build, but `gs` opened 4.3.0
without the profiles tabs (#2588, #2599) or the agent tool cards (#2616).

## What gs sync reports now

- `gs opens: <version> (<path>)`: the version reported by the launch target itself.
- If the launch target differs from `gentle-shell` on PATH, or (consumer) its
  `-main.<sha>` differs from GitHub `gentle-pi` main, or any step fails, it prints
  `INCOMPLETE — failed: ...` and exits 1. It never says "no Pi restart needed" then.
- If GitHub cannot be reached, it warns `freshness unverified` without failing.
- It warns when the legacy checkout still exists. It never deletes it.

## Aligning another machine

Run these on each machine. A machine counts as aligned only after step 3 passes there.

1. Pull the dotfiles so `gs` has this fix: `git -C ~/dev/barbatdev/cortex/cortex-dotfiles pull --ff-only`
   (or let `gs sync` do it on a clean clone on `main`, then run `gs sync` again).
2. Close Pi sessions and run `gs sync`. It must end without `INCOMPLETE`.
3. Check the public entry point:
   ```bash
   gs --version | head -1            # must match the line below
   gentle-shell --version | head -1
   git ls-remote https://github.com/Gentleman-Programming/gentle-pi refs/heads/main
   ```
   On consumer machines the `-main.<sha>` suffix must be a prefix of the remote SHA.
4. Optional cleanup, once step 3 passes: remove the unused legacy checkout
   `~/.pi/agent/git/github.com/Gentleman-Programming/gentle-pi`
   (confirm first that `~/.pi/agent/settings.json` does not list `git:github.com/Gentleman-Programming/gentle-pi`).
5. Open `gs`, then the models screen: profiles appear as tabs.

## Tests

`tests/gs_test.sh` runs offline in a throwaway HOME with stub binaries and covers
the launcher (consumer and workshop, `gs run`, `gs pr`, `gs issue`), the isolated
registration, and the sync result messages.
