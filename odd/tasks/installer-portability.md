# installer-portability

Portability and symlink hardening of `install.sh` per issue #25 (barbatdev/cortex-dotfiles).

## Specs

- S1: Symlink destinations are declared once in a single manifest consumed by backup, symlink creation, and `--check`; no destination missing from any of the three.
- S2: Backup of a symlink destination uses `cp -P`; repo content is never duplicated into `.bak_*`.
- S3: A real (non-symlink) directory at any destination produces a clean pre-flight abort (or explicit dry-run notice), never a mid-run `set -e` abort.
- S4: No duplicate backup calls; `backup_if_exists`/`backup_managed_symlink`/`backup_karabiner_if_exists` collapse into one unified backup path.
- S5: `--check` JSON/TOML globs no longer rely on `**` without `globstar`; each file validated exactly once.
- S6: `local/env.zsh.example` defines `CORTEX_HOME`; every referenced variable is defined or documented.
- S7: README documents `.bak_*` restore steps and backup retention behavior.
- S8: `./install.sh --dry-run` and `./install.sh --check` exit 0 on Linux-style runs (macOS-only branches skipped); re-running install twice creates zero new `.bak_*` files.

## Tasks

- T1 (S1-S5, S8): manifest + unified backup + preflight + manifest-driven --check + find globs in install.sh — commit: 91754ae
- T3 (S6): env.zsh.example CORTEX_HOME — commit: see T4 commit
- T4 (S6-S7): env.zsh.example CORTEX_HOME + README restore/retention docs — commit: (this commit)
- T5 (S8): sandbox verification — commit: pending

## Log

- L1 (user): "si ya" — approval to implement issue #25 (TARS fleet review: needs work → define concrete defects + acceptance criteria; done via issue body update).
- L2: Repo has no automated test runner (AGENTS.md); verification via `bash -n`, `shellcheck` if available, sandbox `$HOME` dry-run/check/real-run/idempotency, per manual-validation convention.
