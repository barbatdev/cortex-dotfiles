# Practical Keymaps

This table favors the shortcuts used by these dotfiles and Herdr defaults. It is a working reference, not a full upstream manual.

## Terminal And Multiplexer

| Tool | Shortcut | Action |
|------|----------|--------|
| Ghostty | `Command+Shift+,` | Reload the active configuration. |
| Ghostty | `Command+K` | Clear the terminal screen. |
| Ghostty | `Shift+Enter` | Send an escaped newline for compatible TUIs. |
| Ghostty | `Option+Left/Right` | Pass word navigation through to the shell. |
| Ghostty | `Option+S` | Write the visible screen to a file and paste its path. |
| Ghostty | `Ctrl+Shift+S` | Write full scrollback to a file and paste its path. |
| Ghostty | `Command+Shift+D` | New outer split down. |
| Ghostty | `Command+Shift+Z` | Toggle outer split zoom. |
| Ghostty | `Ctrl+Option+Left/Right/Up/Down` | Resize outer Ghostty split. |
| Ghostty | `Ctrl+Option+=` | Equalize outer Ghostty splits. |
| Ghostty | select text | Copy selection to clipboard. |
| Ghostty | right click | Paste. |
| tmux (fallback) | `Ctrl+A \|` | New split right. |
| tmux (fallback) | `Ctrl+A -` | New split down. |
| tmux | `Ctrl+A h/j/k/l` | Focus pane left/down/up/right. |
| tmux | `Ctrl+A H/J/K/L` | Resize pane left/down/up/right. |
| tmux | `Option+G` | Toggle scratch popup. |
| Herdr | `Ctrl+A ?` | Help. |
| Herdr | `Ctrl+A Option+K/J` | Focus the previous / next agent. |
| Herdr | `Ctrl+A Ctrl+1..9` | Focus agent 1–9. |
| Herdr | `Ctrl+A q` | Detach client. |
| Herdr | `Ctrl+A w` | Workspace picker. |
| Herdr | `Ctrl+A Shift+N` | New workspace. |
| Herdr | `Ctrl+A Shift+W` | Rename workspace. |
| Herdr | `Ctrl+A Shift+D` | Close workspace. |
| Herdr | `Ctrl+A c` | New tab. |
| Herdr | `Ctrl+A Shift+T` | Rename tab. |
| Herdr | `Ctrl+A p` / `Ctrl+A n` | Previous / next tab. |
| Herdr | `Ctrl+A 1..9` | Switch tab. |
| Herdr | `Ctrl+A Shift+X` | Close tab. |
| Herdr | `Ctrl+A h/j/k/l` | Focus pane left/down/up/right. |
| Herdr | `Ctrl+A Tab` | Cycle pane next. |
| Herdr | `Ctrl+A Shift+Tab` | Cycle pane previous. |
| Herdr | `Ctrl+A v` | Split pane vertically. |
| Herdr | `Ctrl+A -` | Split pane horizontally. |
| Herdr | `Ctrl+A x` | Close pane. |
| Herdr | `Ctrl+A z` | Zoom pane. |
| Herdr | `Ctrl+A Shift+P` | Rename pane. |
| Herdr | `Ctrl+A r` | Resize mode. |
| Herdr | `Ctrl+A b` | Toggle sidebar. |
| Herdr remote | `Ctrl+V` | Remote image paste. |

## AI CLIs

| Tool | Shortcut / Command | Action |
|------|--------------------|--------|
| Claude Code | `cc [path]` | Start Claude Code in the current or given directory. |
| Claude Code | `ccb [path]` | Start Claude Code with explicit permission bypass. |
| Claude Code | `ccx <context> [path]` | Pipe initial context into Claude Code. |
| Claude Code | `ccclip <files>` | Copy files as fenced code context to the clipboard. |
| OpenCode | `oc [path]` | Start OpenCode in the current or given directory. |
| OpenCode | `ocb [path]` | Alias for `oc`, preserving default flags. |

Claude Code and OpenCode keybindings are mostly app-native. This repo adds launch helpers, themes/statusline config, and Herdr integration so sessions survive terminal detach/reattach.

## macOS Windowing

| Tool | Shortcut | Action |
|------|----------|--------|
| Karabiner | tap `Caps Lock` | `Escape`. |
| Karabiner | hold `Caps Lock` | `Left Control`. |
| Karabiner | `Right Command` | `Delete backward`. |

`Option` is the same key macOS labels as `Alt`.

## Collision Notes

| Area | Note |
|------|------|
| Multiplexer prefix | tmux and Herdr intentionally share `Ctrl+A`; only the foreground multiplexer receives it. |
| macOS leader | `Option+Command` is reserved for windowing in this setup; avoid assigning it in Raycast. |
| Ghostty vs multiplexer splits | Use Herdr/tmux splits for persistent work; use Ghostty splits only for outer-terminal layout. |
| Adapted parity | Alan's HJKL actions are aliases under the existing leader; arrow shortcuts and spaces 1–9 remain available. |
| Mouse | Herdr captures mouse by default; prefix keys are more reliable over remote sessions. |

## Related Docs

- [Herdr workflow](herdr-workflow.md)
- [`ghostty/config`](../ghostty/config)
- [`karabiner/karabiner.json`](../karabiner/karabiner.json)
