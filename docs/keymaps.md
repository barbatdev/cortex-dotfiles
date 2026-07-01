# Practical Keymaps

This table favors the shortcuts used by these dotfiles and Herdr defaults. It is a working reference, not a full upstream manual.

## Terminal And Multiplexer

| Tool | Shortcut | Action |
|------|----------|--------|
| Ghostty | `Command+Shift+D` | New split down. |
| Ghostty | `Command+Shift+Z` | Toggle split zoom. |
| Ghostty | `Ctrl+Option+Left/Right/Up/Down` | Resize Ghostty split. |
| Ghostty | `Ctrl+Option+=` | Equalize Ghostty splits. |
| Ghostty | select text | Copy selection to clipboard. |
| Ghostty | right click | Paste. |
| Herdr | `Ctrl+B ?` | Help. |
| Herdr | `Ctrl+B q` | Detach client. |
| Herdr | `Ctrl+B w` | Workspace picker. |
| Herdr | `Ctrl+B Shift+N` | New workspace. |
| Herdr | `Ctrl+B Shift+W` | Rename workspace. |
| Herdr | `Ctrl+B Shift+D` | Close workspace. |
| Herdr | `Ctrl+B c` | New tab. |
| Herdr | `Ctrl+B Shift+T` | Rename tab. |
| Herdr | `Ctrl+B p` / `Ctrl+B n` | Previous / next tab. |
| Herdr | `Ctrl+B 1..9` | Switch tab. |
| Herdr | `Ctrl+B Shift+X` | Close tab. |
| Herdr | `Ctrl+B h/j/k/l` | Focus pane left/down/up/right. |
| Herdr | `Ctrl+B Tab` | Cycle pane next. |
| Herdr | `Ctrl+B Shift+Tab` | Cycle pane previous. |
| Herdr | `Ctrl+B v` | Split pane vertically. |
| Herdr | `Ctrl+B -` | Split pane horizontally. |
| Herdr | `Ctrl+B x` | Close pane. |
| Herdr | `Ctrl+B z` | Zoom pane. |
| Herdr | `Ctrl+B Shift+P` | Rename pane. |
| Herdr | `Ctrl+B r` | Resize mode. |
| Herdr | `Ctrl+B b` | Toggle sidebar. |
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
| skhd/yabai | `Option+Command+Left/Down/Up/Right` | Focus window west/south/north/east. |
| skhd/yabai | `Option+Command+Shift+Left/Down/Up/Right` | Warp or swap window in that direction. |
| skhd/yabai | `Option+Command+1..9` | Focus space. |
| skhd/yabai | `Option+Command+Shift+1..9` | Move window to space and follow it. |
| skhd/yabai | `Option+Command+F` | Toggle float. |
| skhd/yabai | `Option+Command+B` | Balance layout. |
| skhd/yabai | `Option+Command+R` | Reset zero gap, balance, and reload SketchyBar. |
| skhd/yabai | `Option+Command+/` | Show shortcuts help. |
| skhd/yabai | `Option+Command+Shift+R` | Reload yabai, skhd, and SketchyBar. |
| Karabiner | tap `Caps Lock` | `Escape`. |
| Karabiner | hold `Caps Lock` | `Left Control`. |
| Karabiner | `Right Command` | `Delete backward`. |

`Option` is the same key macOS labels as `Alt`.

## Collision Notes

| Area | Note |
|------|------|
| Herdr prefix | `Ctrl+B` avoids most shell and app shortcuts while staying tmux-like. |
| macOS leader | `Option+Command` is reserved for windowing in this setup; avoid assigning it in Raycast. |
| Ghostty vs Herdr splits | Use Herdr splits for persistent work inside a session; use Ghostty splits for outer-terminal layout. |
| Mouse | Herdr captures mouse by default; prefix keys are more reliable over remote sessions. |

## Related Docs

- [Herdr workflow](herdr-workflow.md)
- [`ghostty/config`](../ghostty/config)
- [`skhd/skhdrc`](../skhd/skhdrc)
- [`karabiner/karabiner.json`](../karabiner/karabiner.json)
