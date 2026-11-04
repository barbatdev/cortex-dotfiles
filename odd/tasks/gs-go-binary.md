# gs-go-binary

Objective: replace `bin/gs` and `bin/gs-official` with one deterministic Go binary, identical on Mac local, agent-dev and agent-gentle.
Branch: `feat/gs-go` · Delivery: ask-on-risk · Test runner: `go test ./...` (plus `tests/gs_test.sh` as behavior reference until retired).

## Specs

- S1 — One binary for everything: "vamos a generar un binario determinista para esto con go, no puede ser que mute así esto". Scope answer: "todo" — every current `gs` command (`sync`, `pr`, `issue`, `new`, `review`, `base`, `run`, `ls`, `done`, launch) moves to Go.
- S2 — Same behavior on the 3 machines: "tenemos que dejar todo funcionando bien en las 3 maquinas." (macos local, agent-dev, agent-gentle). No per-host script variants (`gs-official` vs `bin/gs`).
- S3 — Deterministic install layout: one way to place `gentle-ai` and `engram` in `~/.local/bin` (assumption: versioned store + atomic symlink swap, decided in L3); stray installers (`go install` from gentle-ai upgrade) must never replace them; sync verifies the final state and fails loudly (e.g. `engram instance-id` must succeed).
- S4 — GitHub access always through authenticated `gh`: "nosotros acá siempre tenemos que usar gh para estas cosas. Es nuestro entorno controlado y siempre estamos con gh autenticado".
- S5 — `gs doctor` (assumption, proposed in L2 and accepted with "todo"): report in one run every piece out of place on that machine.

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | S1,S3,S5 | inline | pending | — | Go module skeleton, manifest/state model, `gs doctor` |
| T2 | S1,S3,S4 | inline | pending | — | `gs sync` (consumer + workshop) with atomic swap and final verification |
| T3 | S1,S4 | inline | pending | — | worktree commands: `new`, `review`, `pr`, `issue`, `base`, `ls`, `done` |
| T4 | S1 | inline | pending | — | launch / `run` (Pi passthrough) |
| T5 | S2 | inline | pending | — | install via `install.sh`, retire `bin/gs` + `bin/gs-official`, roll out to the 3 machines |

## Log

- L1 (2026-11-04, user, verbatim): "vamos a generar un binario determinista para esto con go, no puede ser que mute así esto somos unos penes. Yo porque hace meses que estoy cone sto y vos porque no podes resolver algo que es una bobada comparada con cosas re jodidas que hacemos"
- L2 (2026-11-04): proposal accepted with scope "todo": manifest, atomic swap, gh for GitHub, final verification, `gs doctor`, replacing both scripts.
- L3 (2026-11-04): context — Mac and agent-dev run `gs-official` (refuses symlinks), agent-gentle runs `bin/gs` (creates symlinks); running the wrong one broke the hosts today. gentle-shell strips GH_TOKEN/GITHUB_TOKEN from children, so its upgrade 403s on the unauthenticated limit.
