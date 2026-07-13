# cmux Workflow

cmux is the default terminal surface for local and remote agent sessions. It reads the shared Ghostty configuration from `~/.config/ghostty/config`; there is no separate cmux theme file.

## Agent Integrations

Install the official lifecycle, Feed, and resume integrations after Claude Code and OpenCode are available:

```bash
cmux hooks setup
```

The dotfiles layer does not replace those hooks. It adds Cortex metadata to the cmux sidebar:

- project and Git branch
- configured brains
- active SDD spec
- Claude model and context progress

## Remote Sessions

Use `sshx` from the Mac to create a persistent cmux SSH workspace:

```bash
sshx agent-dev
```

`cmux ssh` installs its relay daemon on the remote host. Commands such as `cmux notify`, `cmux set-status`, and `cmux set-progress` then update the local Mac workspace through that relay.

Install agent hooks from inside the remote cmux session too, because the agent binaries and their user-level configuration live on the remote host:

```bash
cmux hooks setup
```

Use `sshc agent-dev` only when a conventional SSH shell without cmux persistence or UI integration is intentional.

## Commands

| Command | Purpose |
|---------|---------|
| `cc [path]` | Run Claude Code and publish Cortex metadata |
| `oc [path]` | Run OpenCode and publish Cortex metadata |
| `sshx <host>` | Open a persistent cmux SSH workspace |
| `sshc <host>` | Open a conventional SSH connection |
| `sshx-doctor <host>` | Validate cmux, SSH, and host alias resolution |
| `wtadd <name> [branch]` | Create a worktree and open its agent flow |

cmux owns agent notifications and resume tokens. Cortex scripts should fail silently when the cmux relay is unavailable so the same shell configuration remains usable outside cmux.
