# agent-gentle: workshop gs on the official isolated home

Migrate the dogfooding host agent-gentle off the legacy Pi home without losing the workshop `bin/gs` accessories.
Shell keeps running from the gentle-shell clone; only the home, Pi runtime and Gentle AI registration move to the official layout.

## Specs

- S1. Keep every workshop accessory: "tenemos una serie de accesorios tipo gs issue shell 1234 para revisar un issue o un pr ... revisalo bien antes de arrancar". `gs issue`, `gs pr`, `gs review`, `gs new`, `gs base`, `gs ls`, `gs done` and `gs sync` keep their worktree/git/gh behavior.
- S2. Never `--link`: "Shell y Gentle AI SIEMPRE en main. Nunca release, nunca --link, nunca --include-shared." Every Shell launch in `bin/gs` (`gs`, `gs run`, launches from `gs pr`/`gs issue`) uses the isolated home (`--isolated`) and, from a clone or worktree, keeps `--package-root <root>`.
- S3. No legacy Pi runtime: `bin/gs` does not add `~/.pi/agent/bin` to PATH and does not run `pi update` / `pi update --extensions` in workshop mode. Shell uses the Pi package inside the clone (`node_modules/@earendil-works/pi-coding-agent`).
- S4. Gentle AI from main inside Shell: workshop `gs sync` keeps writing the dev-binary registration `{"schema":"gentle-pi.dev-binary/v1","path":"<~/.local/share/gentle-ai/main/gentle-ai>"}` to `~/.pi/gentle-ai/dev-binary.json` (0600, atomic). It is install-level state the official launcher reads there even for the isolated home (gentle-shell `lib/gentle-shell-launcher.ts:252-254`, `lib/gentle-ai-binary.ts:218` `launcherMarker: false`); it is never moved or retired.
- S5. Prompts for `gs pr` / `gs issue` no longer point at `~/.pi/agent/skills/...`; they name the `cortex-maintainer-delivery` skill without a legacy home path.
- S6. Help text and docs (`docs/gs-sync.md`, `docs/gentle-official-migration.md`) describe the new behavior; `gs-official` and Mac/agent-dev are unaffected.
- S8. Workshop `gs sync` syncs external Gentle AI for Claude Code only and provisions the isolated home: "solo claude code". It runs `gentle-ai sync --agents claude-code` by default (never the legacy `pi` agent nor `opencode`; an explicit `GS_SYNC_AGENTS` still overrides), then `gentle-shell setup` on the isolated home from the synced clone (`node ~/dev/gentle/gentle-shell/bin/gentle-shell.mjs --isolated setup`), the official re-provisioning of `~/.gentle-shell/agent`. `GS_SKIP_AI_SYNC=1` skips both. A failed step marks the sync INCOMPLETE. Consumer sync is unchanged.
- S7. Host deploy on agent-gentle: confirm last NAS backup succeeded; then pull dotfiles, run `gs sync`, replace the `~/.local/bin/gentle-shell` wrapper so it no longer sets `GENTLE_SHELL_PI=~/.pi/agent/bin/pi`, and move retired legacy pieces to a `mktemp -d` backup (never delete). Never touch Engram data, credentials, conversations, worktrees with uncommitted changes, or Herdr.

## Tasks

- T1 (S2-S6) worker + parent fixes: change `bin/gs` + tests + docs. Done. Commit: e89c3d1
- T3 (S8) worker: workshop sync scope + isolated setup. Done. Commit: see branch feat/agent-gentle-sync-scope
- T2 (S7) parent: deploy and verify on agent-gentle. Commit: n/a (host)

## Log

- L1 User: "bueno ahora tenemos que hacer la que para mi es la mas complicada ... capaz no lo es. Agent-gentle es un entorno tipo dogfooding ... yo siendo vos primero miraría bien quehace. Ahí lo que hacemos es trabajar directo con gentle-shell, gentle-ai y engram. Con eso en mente tenemos una serie de accesorios tipo gs issue shell 1234 para revisar un issue o un pr ... revisalo bien antes de arrancar"
- L2 User approved the approach "mantener el gs de workshop y migrar solo su arranque al home aislado": "si".
- L3 Evidence: official launcher (clone 14f44d11c) accepts `--isolated` with `--package-root` (only `--link`+`--isolated` and `--isolated`+`--home` conflict, `lib/gentle-shell-launcher.ts:169-174`); clone has adjacent Pi 1.4.0; isolated home `~/.gentle-shell/agent` already holds pi-mcp-adapter and brains; Engram already at main tip `7cf4ed29b6f9`.
- L4 Parent review: removed the isolated-settings gentle-pi/gentle-engram warning; on agent-gentle the official Shell declares both there (gentle-engram is its required companion), so it would fire on every sync. Skill cortex-maintainer-delivery exists only in ~/.pi/agent/skills on agent-gentle; T2 must expose it to the isolated home before retiring legacy.
- L5 Verifier FAIL on S4: the launcher reads dev-binary.json from ~/.pi/gentle-ai, not the isolated config home (confirmed on agent-gentle clone 14f44d11c, lib/gentle-ai-binary.ts:218). S4 rewritten: keep writing ~/.pi/gentle-ai/dev-binary.json; T1 reopened and fixed.
- L6 User asked whether gs sync also runs gentle-ai sync and whether gentle-shell has its own: "en el gs sync metimos también un gentle-ai sync? porque eso es lo que esta documentado en el proceso de actualizacion. Hay que revisar si gentle-shell no tiene algo de esto también". Finding: workshop runs bare `gentle-ai sync`; installed_agents on agent-gentle = claude-code, opencode, pi, so it keeps syncing the legacy ~/.pi/agent (gentle-shell README: `gentle-ai sync` is Path B, gentle-pi inside an existing pi) and never the isolated home; `gentle-shell setup` re-provisions the isolated home; the agent-gentle wrapper sets GENTLE_SHELL_NO_AUTO_SETUP=1. User decision on agents: "solo claude code".
