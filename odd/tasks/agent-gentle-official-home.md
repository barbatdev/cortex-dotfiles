# agent-gentle: workshop gs on the official isolated home

Migrate the dogfooding host agent-gentle off the legacy Pi home without losing the workshop `bin/gs` accessories.
Shell keeps running from the gentle-shell clone; only the home, Pi runtime and Gentle AI registration move to the official layout.

## Specs

- S1. Keep every workshop accessory: "tenemos una serie de accesorios tipo gs issue shell 1234 para revisar un issue o un pr ... revisalo bien antes de arrancar". `gs issue`, `gs pr`, `gs review`, `gs new`, `gs base`, `gs ls`, `gs done` and `gs sync` keep their worktree/git/gh behavior.
- S2. Never `--link`: "Shell y Gentle AI SIEMPRE en main. Nunca release, nunca --link, nunca --include-shared." Every Shell launch in `bin/gs` (`gs`, `gs run`, launches from `gs pr`/`gs issue`) uses the isolated home (`--isolated`) and, from a clone or worktree, keeps `--package-root <root>`.
- S3. No legacy Pi runtime: `bin/gs` does not add `~/.pi/agent/bin` to PATH and does not run `pi update` / `pi update --extensions` in workshop mode. Shell uses the Pi package inside the clone (`node_modules/@earendil-works/pi-coding-agent`).
- S4. Gentle AI from main inside Shell: workshop `gs sync` writes the dev-binary registration `{"schema":"gentle-pi.dev-binary/v1","path":"<~/.local/share/gentle-ai/main/gentle-ai>"}` to the isolated config home `~/.gentle-shell/gentle-ai/dev-binary.json` (official launcher does not migrate `~/.pi/gentle-ai/dev-binary.json`, see gentle-shell `lib/gentle-shell-launcher.ts:254`).
- S5. Prompts for `gs pr` / `gs issue` no longer point at `~/.pi/agent/skills/...`; they name the `cortex-maintainer-delivery` skill without a legacy home path.
- S6. Help text and docs (`docs/gs-sync.md`, `docs/gentle-official-migration.md`) describe the new behavior; `gs-official` and Mac/agent-dev are unaffected.
- S7. Host deploy on agent-gentle: confirm last NAS backup succeeded; then pull dotfiles, run `gs sync`, replace the `~/.local/bin/gentle-shell` wrapper so it no longer sets `GENTLE_SHELL_PI=~/.pi/agent/bin/pi`, and move retired legacy pieces to a `mktemp -d` backup (never delete). Never touch Engram data, credentials, conversations, worktrees with uncommitted changes, or Herdr.

## Tasks

- T1 (S2-S6) worker + parent fix: change `bin/gs` + tests + docs. Done. Commit: e89c3d1
- T2 (S7) parent: deploy and verify on agent-gentle. Commit: n/a (host)

## Log

- L1 User: "bueno ahora tenemos que hacer la que para mi es la mas complicada ... capaz no lo es. Agent-gentle es un entorno tipo dogfooding ... yo siendo vos primero miraría bien quehace. Ahí lo que hacemos es trabajar directo con gentle-shell, gentle-ai y engram. Con eso en mente tenemos una serie de accesorios tipo gs issue shell 1234 para revisar un issue o un pr ... revisalo bien antes de arrancar"
- L2 User approved the approach "mantener el gs de workshop y migrar solo su arranque al home aislado": "si".
- L3 Evidence: official launcher (clone 14f44d11c) accepts `--isolated` with `--package-root` (only `--link`+`--isolated` and `--isolated`+`--home` conflict, `lib/gentle-shell-launcher.ts:169-174`); clone has adjacent Pi 1.4.0; isolated home `~/.gentle-shell/agent` already holds pi-mcp-adapter and brains; Engram already at main tip `7cf4ed29b6f9`.
- L4 Parent review: removed the isolated-settings gentle-pi/gentle-engram warning; on agent-gentle the official Shell declares both there (gentle-engram is its required companion), so it would fire on every sync. Skill cortex-maintainer-delivery exists only in ~/.pi/agent/skills on agent-gentle; T2 must expose it to the isolated home before retiring legacy.
