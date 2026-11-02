# Engram host repair
Repair Engram after Gentle Shell provisioning and audit agent-dev, agent-gentle and the current Mac.
Preserve memory, credentials, host-specific setup and unrelated edits. Delivery: ask-on-risk; forecast <400 authored lines.

## Specs
S1. User: "arreglalo y revisa el resto de las maquinas incluida esta donde estamos ahora"
S2. Reported failure: active `/home/jbarbat/.local/bin/engram` reports `1.20.1-0.20260902040530-5b2f08fad025` following `gs` provisioning.

## Tasks
T1 [S1-S2] Audit all three hosts, service paths and compatibility; route parent; commit pending; done.
T2 [S1-S2] Repair affected installations with validated backup and recovery path; prevent recurrence via supported profile opt-out; route parent maintenance / bounded worker code; commit pending; done.
T3 [S1-S2] Independently verify host compatibility and relevant launcher checks; route verifier; commit pending; done.

## Log
L5. Root cause independently established: package-local gentle-ai 4.3.1 provisions Engram module without /v3 after gentle-pi version changes. Supported GENTLE_SHELL_NO_AUTO_SETUP=1 blocks automatic startup provisioning; all three installed launchers have the early-return guard. Explicit setup/lifecycle install steps remain outside this mitigation.
L6. Default opt-out deployed to all three shared profiles with targeted edits; Linux pre-edit profiles backed up in ~/engram-auto-setup-backup.*. Existing terminals need export or reload. agent-gentle secondary ~/go/bin/engram v1 preserved, not active. Mac existing zsh/zshrc edit untouched.
L7. Test-first observed RED (beta|unset instead of beta|1), GREEN focused guard. Parent and independent verifier observed focused test, gs-sync checks and zsh syntax exit 0. Independent host checks: v3 module, ready compatibility, exported guard=1 all three. Parent regression command python3 tests/gs_official_test.py && bash tests/gs_test.sh && bash scripts/test-engram-auto-setup.sh && bash scripts/test-gs-sync.sh && git diff --check exited 0. No actual interactive gs or explicit setup launched to avoid unsafe side effects.
L8. Assessment: RDD off, high risk item 5 environment; native assess unassessable due untracked scope, returned self-check plus independent verifier plan, both completed. No native review lifecycle run.
L9. One focused environment work unit on fix/engram-host-repair; commit recorded below. Risk: item 5 (installed executable repair and environment setup). Forecast and actual authored lines <400. No push or PR.
L1. User original request: "arreglalo y revisa el resto de las maquinas incluida esta donde estamos ahora"
L3. Audit: Mac and agent-gentle v3 and compatibility ready. agent-gentle secondary ~/go/bin/engram is v1. agent-dev on-disk v1 but running service v3, compatibility ready.
L4. agent-dev binary-only repair: backed up v1 and running v3 at /home/jbarbat/engram-binary-repair.nf6TZb; SHA256 48c4e4803b4335cb5fd29a6e2738b51b05e1a16a1a46ad2b70b69a30a0b020fa matches /proc/870371/exe; atomically restored v3 module to ~/.local/bin/engram. No memory-store access, service restart or runtime change. Recurrence investigation pending.
L2. Prior read-only SSH: agent-dev-01 active Engram at ~/.local/bin is v1, module lacks /v3. No executable observed at ~/go/bin/engram. Existing human edit zsh/zshrc must be preserved.
