# Official main updates on agent-dev
Branch: feat/official-gs-main. Scope: PATH and minimal official gs on agent-dev; Mac/workshop unchanged.
Delivery: single focused feature branch, no push/PR. Checks: isolated public-command tests, remote functional check, independent item-5 verification.

## Specs
S1. "dale cokn eso ... no me hagas iterar mas contigo hasta que termines ... es cansador esto" — complete the previously proposed permanent PATH and gs/gs sync outcome without intermediate manual checks.
S2. "yo uso gentle-shell y claudecode solamente" — external asset sync must target Claude Code only; preserve other runtime data.
S3. "no no, yo quiero y NECESITO estar siempre apuntando a main" — official Shell upgrade and external AI Go build must use main, not a stable fallback.
S4. "esto tenes que documentarlo para después en el gs sync traerlo siempre de main eh ... no te olvides" — gs sync refreshes external Gentle AI main too; no claim Go install creates a persistent channel.
S5. "gs lo único que tiene que hacer ahora es iniciar gentle-shell, sería un alias a gentle-shell nomas" — default launch forwards arguments unchanged; later S4 adds minimal sync dispatch, no legacy worktree routing or forced --link.
S6. "no borramos memorias.\nno borramos conversaciones ni credenciales." — do not read/copy/delete protected data, change permissions mode, stop sessions or mutate memory stores.

## Tasks
T1 | S1-S6 | delegated | done | launcher, opt-in PATH fragment, 14 tests (RED observed, GREEN) and docs | 2121ea4, 07248f6.
T2 | S1,S2,S6 | inline | done | deployed gs + fragment on agent-dev without overwriting; marked ~/.zshenv bridge until the remote clone pulls the merge | no repo commit (host deploy).
T3 | S1-S6 | inline + independent verifier | done | real gs sync exit 0; verifier PASS S1-S6, no defects | this commit.

## Log
L1. User request: "dale cokn eso ... no me hagas iterar mas contigo hasta que termines ... es cansador esto"
L2. Preceding accepted scope: permanent CodeGraph PATH and new gs/gs sync updating Shell and external AI always main. agent-dev only; no migration of Mac or workshop. Preserve old bin/gs on other hosts by adding bin/gs-official deployed as ~/.local/bin/gs only on migrated agent-dev. Root main has three untracked documentation/retirement files from prior authorized work; preserve them, work in separate feature worktree.
L4. Deploy evidence: fresh interactive zsh on agent-dev resolves gs=~/.local/bin/gs, gentle-shell=pnpm bin, gentle-ai=~/.local/bin, codegraph=~/npm-global/bin, go=/usr/local/go/bin. Real `gs sync` exit 0: Shell already latest main 49b3bff8c154 (internal AI c60a4b6d5675); external AI @main c60a4b6d5675 (go version -m pseudo-version); `sync --agents claude-code` changed 3 files. Bridge line in ~/.zshenv carries the marker '# official-gentle-path bridge (remove after dotfiles merge)'. Push/PR/merge left to the user; slice 765 lines in 2 work-unit commits.
L5. Deploy verifier (mvwbipqk-5-0myn, Risk item 5): checks 1-3 and 5-7 PASS (sha256 match for gs and fragment, single bridge marker, help rc0, `sync extra` rc2, main builds, legacy Pi/Orca still retired). Check 4 found ~/.local/bin twice in interactive PATH. Reproduced with an empty .zshenv via ZDOTDIR: count is 2 without the bridge too, so it predates this change (some later startup file prepends it again; private files not read). A simulated merged zshrc (fragment sourced last) gives count 1, so the merge removes it. Live `gs sync` and arg forwarding not re-run by the verifier (sync mutates; parent's real run already exit 0).
L3. Risk item 5: official upgrades and environment PATH. Default-launch contract and workshop preserved by separate launcher, no shared helper changes. Forecast about 300 authored lines for launcher/tests/docs; no broad legacy removal.
