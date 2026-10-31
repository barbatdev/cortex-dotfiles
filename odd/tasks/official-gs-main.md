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
T1 | S1-S6 | delegated | in_progress | implement minimal opt-in launcher, focused tests and docs; no changes to legacy gs or shared profile | commit pending.
T2 | S1,S2,S6 | inline | pending | persistent PATH and deploy verified launcher to agent-dev with rollback backup, preserve remote unrelated changes | commit pending.
T3 | S1-S6 | inline + independent verifier | pending | assess item 5, run public checks and real sync, record outcomes and close | commit pending.

## Log
L1. User request: "dale cokn eso ... no me hagas iterar mas contigo hasta que termines ... es cansador esto"
L2. Preceding accepted scope: permanent CodeGraph PATH and new gs/gs sync updating Shell and external AI always main. agent-dev only; no migration of Mac or workshop. Preserve old bin/gs on other hosts by adding bin/gs-official deployed as ~/.local/bin/gs only on migrated agent-dev. Root main has three untracked documentation/retirement files from prior authorized work; preserve them, work in separate feature worktree.
L3. Risk item 5: official upgrades and environment PATH. Default-launch contract and workshop preserved by separate launcher, no shared helper changes. Forecast about 300 authored lines for launcher/tests/docs; no broad legacy removal.
