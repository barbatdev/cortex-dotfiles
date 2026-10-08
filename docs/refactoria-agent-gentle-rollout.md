# RefactorIA CLI visuals on agent-gentle

The Linux/Fish rollout is **applied and visually approved** on `agent-gentle` (2026-09-27). This is a per-tool manual recipe and recovery record, **not** an all-tool installer. Pi's guarded batch installed only the theme for `pi --use-theme refactoria`. After visual use, its saved default changed from the initially preserved `Gentleman-Sexy` to `refactoria`; the user explicitly chose to **keep RefactorIA as the saved default**. We did not write Pi settings in the guarded batch. No Zsh, Ghostty, Neovim, SketchyBar, Herdr binary patch, package installation, app restart, or broad `install.sh` was involved.

> **Source availability:** Use the selected feature-branch revision containing the nine Linux replay inputs below. Until those commits are published, an ordinary remote clean clone will not contain them. The Mac `herdr/config.toml` is a separate visual-only change: local onboarding/keys/UI settings must not be copied or staged wholesale. Do not take assets from `main` by assumption, and do not run the rejected `scripts/refactoria_linux.py` or the superseded all-tool draft.

## Quick path for a future manual replay

1. Select an **explicit** source tree containing the nine replay files and SHA-256s below. Confirm the destination is the intended Linux account/worktree and use the existing pinned SSH alias only: `ssh -o HostKeyAlias=agent-gentle -o StrictHostKeyChecking=yes -o UpdateHostKeys=no agent-gentle`.
2. Work **one tool at a time** in the order below. Inspect every destination's `lstat` type, mode, owner, SHA-256 or absence; refuse symlinked ancestors and any unexpected baseline. Stage only that tool's source files in a new owned `0700` directory beneath `~/.local/state/refactoria-staging/` and verify source hashes there.
3. Before a target write, create a unique owned `0700` directory beneath `~/.local/state/refactoria-backups/`. Copy each existing exact target as a `0600` file and write `0600` absence markers for targets that do not exist. Check backup hashes, then recheck the entire live baseline. Never print a settings file or its secrets.
4. Generate the candidate for that tool, compare **nonvisual** settings semantically with the backed-up original, parse it and run its isolated checker. Write only approved target paths. Create absent files exclusively (same-directory unique temporary file plus no-clobber link); replace existing files with a same-directory temporary file and rename, preserving the original mode/owner. Recheck immediately before each write. A failed or drifted step stops the tool batch; do not advance automatically.
5. Verify hashes, permissions, parsers, tool-specific runtime checks and a **fresh human visual check** before the next tool. Keep backup and staging intact. To restore, first inspect the live hashes: restore an existing original only when live bytes are the recorded candidate, and remove a newly created file only when its bytes still match the recorded source; skip drifted paths for manual review. Never restore by wildcard or from an unverified backup. A created but now empty `profiles/` or `themes/` directory may intentionally remain after file rollback.

This procedure is deliberately operator-driven: a script's passing rehearsal does not authorize replacing a different baseline. The current host-specific staged one-off scripts are recovery aids for the **exact** snapshots below, not a portable installer.

## Approved Linux replay inputs (nine files)

| Repository path | SHA-256 |
|---|---|
| `herdr/profiles/refactoria.toml` | `db5fb9e9c2cfa2b2c71ec389eaf7dff35596cfeee655740e237013c0d7816e33` |
| `pi/themes/refactoria.json` | `add53fd1744a052af7630508257b0cd6cfc7e53739088370207408f5918347ee` |
| `claude/themes/refactoria.json` | `8f2c3994416a352da5c121ce1831eb65cdbdb59f85324ec8542a2b0489e1020e` |
| `claude/statusline-command.sh` | `8b3524b8f1c9279f19986dbef7be0e3230d9044868d6f21b44b5ad85c40e454c` |
| `opencode/themes/refactoria.json` | `612dd0a82986d8ea9f5478867aed8d6f29e525c3ee37cf2662749a0d2bd6276a` |
| `starship/starship.toml` | `e03def24fa28f3dacf43918f0604e096220f3e02cf4d6c9324c17fd25415acf5` |
| `fish/themes/refactoria.fish` | `3b04a53612cf0c0f76dea3b9e6c08f4485c24a451eac46a332ede9d00b5b9583` |
| `fish/functions/fish_greeting.fish` | `15450023712b8c517cd1203e8de636425c97b669d6f3b9f1af403184ef904f6c` |
| `fish/functions/help-profile.fish` | `b079bdc6110cfb55e129cd84654f93951d014b1a7d817df682df21f904a22626` |

## Applied destinations and recovery boundaries

All paths below are relative to `/home/jbarbat`; installed files are regular and owned by uid/gid `1000/1000`. The backup root for each row group is `~/.local/state/refactoria-backups/<id>/` (directory `0700`, saved files/markers `0600`). **Absent** means no pre-rollout file existed. The approved after-hashes bind a guided restore; never use a backup for a different target identity.

| Tool / backup `<id>` | Exact destination | Before | Approved after |
|---|---|---|---|
| Herdr / `herdr-_dvfiir9` | `.config/herdr/config.toml` | `d618349e…bc95ca4` | `cc60b9668a7f162516a94bbee3b23c3e3aa8bcfaebc9e90b6eea5e3e2403b945` (0644) |
| | `.config/herdr/profiles/refactoria.toml` | absent | `db5fb9e9…6e33` (0644) |
| Pi / `pi.oZ39kbUB` | `.pi/agent/themes/refactoria.json` | absent | `add53fd17…347ee` (0644) |
| Claude / `claude.7rr9KBTd` | `.claude/settings.json` | `7fe09aff…2323f6` | `3c4e1bbf8ee61dfd7d957193e92683a599b6da81eddd73b84536dae8dd7338ef` (0644) |
| | `.claude/themes/refactoria.json` | absent | `8f2c3994…e1020e` (0644) |
| | `.claude/statusline-command.sh` | absent | `8b3524b8…e454c` (0755) |
| OpenCode / `opencode.qqD2OtS1` | `.config/opencode/opencode.json` | `2f9a1c89…32b3d` | `1dbba72622cb6459b6c75906fc1d9ac352f1c7917d3c039f4ca079ae23315fd6` (0644) |
| | `.config/opencode/tui.json` | `fe85e04e…cb38c8c` | `c450eaa8533ee5a06570dabeacba164e2f51627ebf9ba10a3863409b42bc1c21` (0644) |
| | `.config/opencode/themes/refactoria.json` | absent | `612dd0a8…6276a` (0644) |
| Starship / `starship.M761Rlpy` | `.config/starship.toml` | `978c7203…fc1db` | `e03def24fa28f3dacf43918f0604e096220f3e02cf4d6c9324c17fd25415acf5` (0644) |
| Fish / `fish.aT7Q5jpk` | `.config/fish/themes/refactoria.fish` | absent | `3b04a536…b9583` (0644) |
| | `.config/fish/conf.d/zz-refactoria-theme.fish` | **`8ebfb078e66c0c0109dbc1708a4060a7f4a93f13fa2494d41164218c89fdedfb`** | `b0cb6463e40437d772afc12e0b3577428d540528eb5ab2dafb706c8b2a086ea8` (0644) |
| | `.config/fish/functions/fish_greeting.fish` | absent | `15450023…4f6c` (0644) |
| | `.config/fish/functions/help-profile.fish` | absent | `b079bdc6…2626` (0644) |

**Post-rollout Claude drift:** `.claude/settings.json` now has SHA `cea2d41181e38bd439c919b64fa039d73fae6fa99c41525f94ecc1c69120787e`, not its guarded after-hash in the table. The approved `theme`/`statusLine` remain exact, the five original keys still deep-equal the private backup, and `skipDangerousModePermissionPrompt` was added later (cause unknown). **The staged byte-guarded settings rollback must stop on this drift**; do not restore the old JSON over that key. Any desired reversal of the two visual selectors requires a separately backed-up, reviewed semantic merge.

**Guarded during our applications:** `.config/fish/config.fish` SHA `9d784d88e78620d459d01c8e385851df6f46d675f28fcfe6eb2db3c7facdfeb5` retains host setup. We wrote **14** target files; `.pi/agent/settings.json` was not one of them and remained SHA `3f3b6489…b900` with `Gentleman-Sexy` immediately after our Pi batch. After visual use, its current SHA is `e41d483e74d48a3ff02594ac4b60be09160110a65284f2880a0078cc965f0067` with `theme="refactoria"`. The user explicitly chose to keep this current default. On another host, choosing a saved default is a **separate guarded settings backup/semantic merge**, not implied by copying the theme; the original current-host settings bytes were not backed up by the Pi theme batch.

## Per-tool decisions and checks

| Tool | Candidate construction and verification | Visual result |
|---|---|---|
| Herdr 0.9.1 | Use the portable `herdr/profiles/refactoria.toml` as visual input for `scripts/refactoria_herdr.py:plan_visual_merge`; it modifies only `[theme]` name/auto_switch/custom roles and `[ui] accent` in the existing config, preserving unrelated TOML/comment lines including `[[remote]]`. Validate under private `XDG_CONFIG_HOME` with `herdr config check`, then after apply. Copy the same profile separately. The profile and current Mac config have identical merge input roles; do not take Mac-only settings as Linux input. | Approved in a fresh Herdr session. |
| Pi 0.87.1 | Copy the user theme first; `pi --use-theme refactoria` proves the theme without a settings change. The user later selected `refactoria` as the **saved default**. For a future host, separately back up and semantic-merge just the `theme` key if that default is desired, preserving all other settings; do not assume Pi application itself edits the selector. | Approved in a fresh Pi invocation; saved RefactorIA default retained by user choice. |
| Claude Code 2.1.283 | Deep-copy JSON settings; add `theme="custom:refactoria"` and `statusLine={"type":"command","command":"bash ~/.claude/statusline-command.sh"}` only. Preserve all five other keys; copy theme and executable minimal statusline. `bash -n`, `jq` availability and a synthetic 80%/UTF-8 fixture passed. | Approved in a fresh Claude session. |
| OpenCode 1.18.32 | In `opencode.json`, change `theme="system"` to `"refactoria"`; in `tui.json`, add only `theme="refactoria"`. Preserve all other JSON values and copy theme. | Approved in a fresh OpenCode session. |
| Starship 1.26.0 | Replace **only** the recognized `978c…fc1db` baseline with the source TOML. `starship print-config` and `starship prompt` passed against both an isolated candidate and the live config. | Approved in a fresh Fish shell. |
| Fish 4.9.2 | Copy three sources; replace the exact old full-theme activation with the one-line wrapper `source "$HOME/.config/fish/themes/refactoria.fish"`. Preserve `config.fish`. `fish -n` and an isolated sourced greeting/help invocation passed; unavailable helpers are filtered by `type -q`. | Approved in a fresh Fish shell with `help-profile`. |

## Unfinished delivery and cleanup

- At the time of host rollout, no commit, push, merge or full installer ran. The user later authorized **scoped work-unit commits only** on the feature branch. Push/PR/merge remain separate decisions. Repository-local dirty work predates this rollout; do not stage it wholesale.
- Private host backups and per-tool staging remain on `agent-gentle` for recovery. The two misplaced Starship rehearsal fixtures at `/home/jbarbat/dev/refactoria-rehearsal-fixture` and `...fixture2` were removed after explicit user approval and fresh exact-tree validation; the real Starship backup/stage and other isolated private-stage fixtures were retained.
- The rejected all-tool auto script and 323-line Herdr transaction draft, plus their two paired tests, were removed as **four exact untracked files** after the user authorized cleanup. Other drafts and generated bytecode were deliberately left untouched. The only executable rollback helpers for this host are the private staged one-off scripts bound to the backup IDs above; first run their preview and compare hashes, then use the explicit confirmation route if recovery is actually needed.
