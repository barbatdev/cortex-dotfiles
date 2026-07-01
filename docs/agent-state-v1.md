# Cortex Agent State v1

`cortex.agent_state.v1` defines a small event contract for reporting agent activity to Cortex UI surfaces. It is inspired by the separation in `gentle-agent-state` and by Herdr's pane-oriented reporting API: adapters translate native agent signals into this contract, and renderers consume only the normalized state.

## Purpose

- Provide one stable anti-corruption layer between agent-native events and Cortex surfaces such as Herdr, SketchyBar, statuslines and desktop notifications.
- Make agent state comparable across tools without requiring every UI to understand every agent.
- Keep state ephemeral, privacy-preserving and safe to roll up across panes, sessions and workspaces.
- Define the contract before implementing runtime adapters.

## Non-Goals

- This is not a task tracker, job queue or durable audit log.
- This does not define agent-specific protocols, prompt formats or tool-call telemetry.
- This does not require storing prompts, completions, command output or file contents.
- This does not define UI layout, icons, colors or notification copy.
- This does not replace Herdr pane metadata; it maps into it.

## Canonical States

| State | Meaning | Examples |
|-------|---------|----------|
| `working` | The agent is actively processing, executing tools or waiting on a known in-flight operation. | Streaming response, running tests, applying a patch. |
| `blocked` | The agent cannot proceed without user input, external approval, credentials, a failed dependency or a recoverable error. | Permission needed, merge conflict, missing secret, test failure requiring decision. |
| `idle` | The agent is available and has no known active work. | Ready prompt, completed turn, waiting for next instruction. |
| `unknown` | The adapter cannot determine current state or the last event is stale. | Unsupported source, crashed adapter, expired TTL. |

`done` is not canonical. If a source emits `done`, adapters should report a transition to `idle` with `reason: "done"` or `native_state: "done"`. Renderers may display that as a short-lived completed affordance, but persisted rollups must treat it as `idle`.

## Event Schema

Events are append-style reports. Consumers should treat the newest non-stale event per `agent_id` and `pane_id` as authoritative.

Required fields:

- `schema`: constant string `cortex.agent_state.v1`.
- `state`: one of `working`, `blocked`, `idle` or `unknown`.
- `source`: adapter identity.
- `agent`: logical agent identity.
- `context`: pane/session/workspace identity.
- `observed_at`: when the adapter observed the native state.
- `expires_at`: when consumers must treat the event as stale.

Recommended optional fields:

- `event_id`: unique event identifier for dedupe.
- `sequence`: monotonic counter scoped to the source and context.
- `reason`: short machine-readable transition reason.
- `message`: short user-facing summary safe for local display.
- `native_state`: original source state before normalization.
- `visibility`: whether notifications should be suppressed for visible surfaces.
- `metadata`: small, non-sensitive adapter metadata.

```json
{
  "schema": "cortex.agent_state.v1",
  "event_id": "01JZ7W31B6TNTV4V7TR8R3XG2D",
  "sequence": 42,
  "state": "blocked",
  "reason": "needs_user_input",
  "message": "Review required before continuing",
  "native_state": "awaiting_approval",
  "source": {
    "adapter": "claude-code",
    "adapter_version": "0.1.0",
    "host": "macbook-pro"
  },
  "agent": {
    "agent_id": "claude:repo:cortex-dotfiles",
    "agent_kind": "claude-code",
    "display_name": "Claude Code"
  },
  "context": {
    "workspace_id": "cortex-dotfiles",
    "repo_path": "/home/jbarbat/dev/barbatdev/cortex/cortex-dotfiles",
    "session_id": "herdr:main:1",
    "pane_id": "herdr:main:1.2",
    "surface": "herdr"
  },
  "visibility": {
    "pane_visible": true,
    "suppress_notifications": true
  },
  "observed_at": "2026-07-01T15:04:05Z",
  "expires_at": "2026-07-01T15:05:05Z",
  "metadata": {
    "branch": "docs/agent-state-v1",
    "issue": 13
  }
}
```

## Identity Fields

Identity must be stable enough for rollups and cheap enough for shell adapters.

| Field | Stability | Guidance |
|-------|-----------|----------|
| `agent.agent_id` | Stable per logical agent in a workspace. | Prefer `<agent-kind>:<scope>:<workspace>`. Do not include secrets or full prompt text. |
| `agent.agent_kind` | Stable per integration. | Examples: `claude-code`, `opencode`, `codex`, `custom`. |
| `agent.display_name` | Human-readable. | Safe to show in UI; not used for dedupe. |
| `context.workspace_id` | Stable per project/workspace. | Prefer repo basename or Herdr workspace name. |
| `context.repo_path` | Local-only absolute path. | Optional outside local adapters; never publish remotely. |
| `context.session_id` | Stable per terminal/session container. | Use Herdr session/window identity when available. |
| `context.pane_id` | Stable per pane. | Required for pane-level rollups. |
| `context.surface` | Reporting surface. | Examples: `herdr`, `tmux`, `statusline`, `sketchybar`. |

## Timestamps, TTL And Staleness

- `observed_at` and `expires_at` must be RFC 3339 UTC timestamps.
- Adapters should use short TTLs for active states: 30-120 seconds for `working` and `blocked`.
- `idle` may use a longer TTL, but consumers should still expire it to `unknown` after missed heartbeats.
- Consumers must treat events as `unknown` after `expires_at`, even if the last state was `working` or `blocked`.
- Consumers should prefer source timestamps over receive time, but may reject events too far in the future.
- Stale cleanup should delete or ignore expired records; it must not send notifications.

## Sources And Adapters

Adapters are responsible for translating native events into canonical states.

- Claude Code hooks may map tool execution and permission waits to `working` or `blocked`.
- OpenCode hooks may map active turns to `working` and prompt-ready states to `idle`.
- Herdr pane observers may report `unknown` when a pane disappears or cannot be inspected.
- Shell wrappers may emit coarse `working` and `idle` transitions around long-running commands.

Adapters should preserve the original source value in `native_state` when it helps debugging, but consumers must not depend on that value for behavior.

## Rollup Order

When multiple pane or agent states are summarized, consumers must use this priority order:

```text
blocked > working > idle > unknown
```

Rules:

- Any fresh `blocked` child makes the parent `blocked`.
- Otherwise any fresh `working` child makes the parent `working`.
- Otherwise any fresh `idle` child makes the parent `idle`.
- If no fresh known child exists, the parent is `unknown`.
- Rollups should include counts by state when space allows, but the primary parent state follows the priority order.

## Notifications

Notifications are transition-only.

- Notify only when the effective state changes after staleness filtering and rollup.
- Do not notify on heartbeat refreshes with the same state.
- Do not notify when stale cleanup changes a state to `unknown`.
- Prefer notifying on `blocked` transitions; avoid noisy `working` notifications unless explicitly enabled.
- Treat `done` as an optional `idle` transition with a short-lived renderer affordance, not as a durable state.

## Visibility Suppression

Visible panes should not spam the user.

- If the relevant pane or surface is focused/visible, adapters or renderers should set `suppress_notifications: true`.
- Hidden panes may notify on important transitions such as `working -> blocked`.
- Renderers should still update visual state even when notifications are suppressed.
- Visibility checks are best-effort. Missing visibility data must not block state reporting.

## Minimal Local CLI

The first runtime slice is a neutral local command backed only by POSIX shell and `python3`:

```bash
cortex.agent_state.v1 report --source opencode --agent opencode:cortex-dotfiles --state working --message "running tests"
cortex.agent_state.v1 list
cortex.agent_state.v1 get --agent opencode:cortex-dotfiles
cortex.agent_state.v1 clear
```

`agent-state` is an alias for the same command when `zsh/zshrc` is loaded. The command records only caller-provided `message` text plus allowlisted Herdr context environment fields when present: `HERDR_PANE_ID`, `HERDR_SESSION` and `HERDR_WORKSPACE_ID`. It does not inspect prompts, command output, file contents or arbitrary environment variables.

When running inside Herdr (`HERDR_ENV=1` or `CORTEX_MULTIPLEXER=herdr`) with `HERDR_PANE_ID` set and a `herdr` binary available on `PATH`, `report` also makes a best-effort pane update:

```bash
herdr pane report-agent "$HERDR_PANE_ID" --source cortex.agent-state --agent "$agent" --state "$state" --message "$message"
```

The Herdr call is optional and never blocks the local state write. Set `CORTEX_AGENT_STATE_HERDR=0` to disable it. The bridge skips `unknown` states because they are useful for the local contract but not useful as pane status updates.

## Storage Guidance

State storage should be local, ephemeral and overwrite-friendly.

- Use a state path such as `${XDG_STATE_HOME:-~/.local/state}/cortex/agent-state/`.
- The minimal CLI appends events to `events.jsonl` and stores current records in `current/`.
- Store one latest JSON record per stable `context.pane_id` or per `agent_id` plus `pane_id`.
- Keep optional append logs disabled by default and rotate aggressively when enabled for debugging.
- Do not store prompts, model output, command output, file diffs, tokens, credentials or environment dumps.
- Expire stale files during reads or with a lightweight cleanup job.
- Runtime implementations may choose JSON files, SQLite or Herdr-native metadata, but the external shape remains `cortex.agent_state.v1`.

## Herdr Integration

Herdr is the preferred local surface for pane-scoped state.

Mapping guidance:

| Cortex field | Herdr API mapping |
|--------------|-------------------|
| `context.pane_id` | Herdr pane identifier. |
| `context.session_id` | Herdr session/window identifier. |
| `state` | `report-agent` state payload. |
| `agent.agent_id` | `report-agent` logical agent id. |
| `agent.display_name` | `report-agent` display label. |
| `message`, `reason` | `report-agent` summary/status fields. |
| `source`, `observed_at`, `expires_at`, `visibility`, `metadata` | `report-metadata` payload. |

Expected adapter flow:

1. Normalize the native agent event to `cortex.agent_state.v1`.
2. Send useful non-`unknown` states through Herdr `report-agent` for pane-visible status.
3. Let Herdr or downstream renderers apply rollup order, TTL and notification rules.

The first local bridge only reports semantic state via `report-agent`; richer metadata reporting is left to a later adapter slice.

Herdr-specific extensions must live under `metadata.herdr` so generic consumers can ignore them safely.

## Security And Privacy

- Never include secrets, tokens, credentials, private keys, cookies or full environment dumps.
- Never include prompt text, model output, command output, patch content or arbitrary file contents.
- Prefer local-only paths and identifiers; do not sync state files by default.
- Keep messages short and display-safe because status bars and notifications are visible in screenshots and screen shares.
- Treat `metadata` as allowlisted, not a dumping ground for raw adapter payloads.
- Adapters should fail closed to `unknown` when they cannot safely classify or sanitize an event.

## Rollout Phases

1. **Spec**: land this document and keep runtime behavior unchanged.
2. **Fixture**: add sample events and a tiny validator for local development.
3. **Adapter prototype**: implement one low-risk adapter, preferably Herdr-facing and local-only.
4. **Renderer integration**: show state in Herdr/statusline without notifications enabled by default.
5. **Notification gate**: enable transition-only notifications for hidden panes and `blocked` transitions.
6. **Multi-agent rollups**: aggregate pane, workspace and repo states using the canonical priority order.
7. **Hardening**: add TTL cleanup, privacy tests and adapter compatibility notes before broader use.
