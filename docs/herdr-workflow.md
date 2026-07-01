# Herdr Workflow Reference

This workflow keeps terminal state persistent across local and remote work while leaving Ghostty as the outer terminal and Herdr as the workspace manager.

## Quick Path

1. Open a repo session with `hhere` or a role session with `hfocus`, `hside`, or `hscratch`.
2. Split work by Herdr workspace, tab, and pane instead of opening anonymous terminal windows.
3. Run `cc` or `oc` inside the relevant pane; Herdr provides persistence and reattach.
4. Use `whereami` when context is unclear.
5. Detach with `Ctrl+B q` and reattach with the same helper or `herdr --session <name>`.

## Local And Remote Modes

| Mode | Use | Command |
|------|-----|---------|
| Local Herdr | Normal work on the current machine | `hhere [path]`, `hfocus [path]` |
| Remote Herdr bridge | Persistent remote session rendered through the local client | `hremote <host> [session]` |
| Plain SSH/Mosh first | You need a normal remote shell before deciding what to run there | `sshx <host>`, `moshx <host> [path]` |

`hremote` is not the same thing as `ssh` followed by `herdr`. `hremote` uses `herdr --remote` and attaches to a named Herdr session on the host through Herdr's remote bridge. `sshx` or `moshx` gives you a regular remote shell; from there, `hhere` starts or attaches Herdr as a local process on that remote host.

In `hremote`, `Ctrl+V` is reserved by Herdr for remote image paste when supported by the terminal. Use normal shell paste bindings outside remote attach.

## Naming Conventions

| Level | Convention | Example |
|-------|------------|---------|
| Session | Host + repo + branch + optional role | `local-mac-cortex-dotfiles-docs-herdr-workflow-reference-focus` |
| Workspace | Repo/branch or operational label | `cortex-dotfiles-docs-herdr-workflow-reference` |
| Tab | One objective or phase | `docs`, `verify`, `review` |
| Pane | One actor or process | `shell`, `cc`, `oc`, `tests`, `logs` |

Prefer human names over physical monitor names. `focus`, `side`, and `scratch` describe intent and survive moving between laptops, external displays, and remote machines.

## Daily Helpers

| Helper | Use |
|--------|-----|
| `hhere [path]` / `hmain [path]` | Enter the main Herdr session for the repo/branch. |
| `hfocus [path]` | Enter the main intense-work role session. |
| `hside [path]` | Enter a lateral session for references, logs, or review. |
| `hscratch [path]` | Enter a disposable session for experiments. |
| `hname [label]` | Rename the current pane so the sidebar stays readable. |
| `whereami` | Print host, cwd, repo, branch, SSH context, and Herdr pane id. |
| `cc [path]` | Start Claude Code in the current or given directory. |
| `oc [path]` | Start OpenCode in the current or given directory. |

When already inside Herdr, the `h*` helpers do not nest Herdr by default. They create or focus a workspace in the current Herdr session.

## Workspace Layout

Use this as the default shape for coding sessions:

| Area | Contents |
|------|----------|
| Main workspace | Active repo, implementation pane, agent pane, verification pane. |
| Side workspace | Docs, notes, logs, PR context, references. |
| Scratch workspace | Risky commands, temporary experiments, reproduction attempts. |

Tabs should mark objectives, not tools. Panes should mark long-lived actors or processes. If a pane will stay open, name it with `hname`.

## Mouse And Prefix Keys

Herdr captures mouse input by default, which is useful for focusing panes, using the sidebar, and direct pane actions. Prefix keys remain the reliable path for remote sessions, keyboard-only work, and terminals where modified mouse gestures are inconsistent.

| Task | Prefer |
|------|--------|
| Quick pane focus or sidebar selection | Mouse |
| Remote attach, repeatable muscle memory, detach/reattach | Prefix keys |
| Pane splits, close, zoom, rename | Prefix keys |
| App-specific mouse inside lazygit/btop/etc. | Let the app request mouse support |

The default Herdr prefix is `Ctrl+B`. See [keymaps](keymaps.md) for the practical table.

## Detach And Reattach

| Action | Command |
|--------|---------|
| Detach current Herdr client | `Ctrl+B q` |
| Reattach main local repo session | `hhere [path]` |
| Reattach role session | `hfocus [path]`, `hside [path]`, `hscratch [path]` |
| Reattach explicit session | `herdr --session <name>` or `herdr session attach <name>` |
| Reattach remote session | `hremote <host> [session]` |

Before detaching long-running work, name important panes and run `whereami` if the shell context is ambiguous.

## Related Docs

- [Keymaps](keymaps.md)
- [Practical keymaps](keymaps.md)
- [Cortex Agent State v1](agent-state-v1.md)
- [README](../README.md)
