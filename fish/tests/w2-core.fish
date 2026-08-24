#!/usr/bin/env fish

set -l repo_root (cd (dirname (dirname (status filename))); and pwd)
set -l core "$repo_root/conf.d/10-core.fish"
set -g functions_dir "$repo_root/functions"
set -g workspace (mktemp -d)
if test -z "$workspace"
    printf 'FAIL: could not create temporary workspace\n' >&2
    exit 1
end

function _cleanup_workspace --on-event fish_exit
    test -d "$workspace"; and rm -rf -- "$workspace"
end

set -g home "$workspace/home"
set -g xdg "$home/.config"
set -g bin "$workspace/bin"
mkdir -p "$xdg/fish/conf.d" "$bin"
printf '#!/bin/sh\n' >"$bin/nvim"
chmod +x "$bin/nvim"

function fail
    printf 'FAIL: %s\n' "$argv" >&2
    exit 1
end

set -g fish_bin (status fish-path); and test -n "$fish_bin"; or fail 'could not resolve Fish interpreter'
function assert_equal
    test "$argv[1]" = "$argv[2]"; or fail "$argv[3] (expected '$argv[2]', got '$argv[1]')"
end

function run_fish
    env -i HOME="$home" USER=test-user LOGNAME=test-user XDG_CONFIG_HOME="$xdg" PATH="$bin:/usr/bin:/bin" TERM=xterm-256color LANG=C "$fish_bin" $argv
end

function run_clean_fish
    env -i HOME="$home" USER=test-user LOGNAME=test-user XDG_CONFIG_HOME="$xdg" PATH="$bin:/usr/bin:/bin" TERM=xterm-256color LANG=C "$fish_bin" --no-config $argv
end

function assert_navigation_error
    set -l command "$argv[1]"
    set -l expected "$argv[2]"
    set -l description "$argv[3]"

    run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; $command" >/dev/null 2>"$workspace/error"; and fail "$description must fail"
    grep -Fq "Directory not found: $expected" "$workspace/error"; or fail "$description error message"
end

cp "$core" "$xdg/fish/conf.d/10-core.fish"
set -l defaults (run_fish -c 'string join "|" $WORKSPACE_DIR $BARBATDEV_DIR $CORTEX_HOME $CORTEX_ROOT $CORTEX_DOTFILES_DIR $CORTEX_MULTIPLEXER $CLAUDE_CODE_EFFORT_LEVEL $WORK_PROJECTS_DIR $PERSONAL_PROJECTS_DIR $INNIT_DIR $SCREENSHOTS_DIR $EDITOR $VISUAL')
assert_equal "$defaults" "$home/dev|$home/dev/barbatdev|$home/.cortex|$home/dev/barbatdev/cortex/cortex|$home/dev/barbatdev/cortex/cortex-dotfiles|cmux|high|$home/dev/barbatdev/innit|$home/dev/barbatdev/products|$home/dev/barbatdev/innit|$home/Screenshots|$bin/nvim|$bin/nvim" 'defaults and editor selection'

set -l empty_defaults (env -i HOME="$home" USER=test-user LOGNAME=test-user XDG_CONFIG_HOME="$xdg" PATH="$bin:/usr/bin:/bin" TERM=xterm-256color LANG=C WORKSPACE_DIR= BARBATDEV_DIR= CORTEX_HOME= CORTEX_ROOT= CORTEX_DOTFILES_DIR= CORTEX_MULTIPLEXER= CLAUDE_CODE_EFFORT_LEVEL= WORK_PROJECTS_DIR= PERSONAL_PROJECTS_DIR= INNIT_DIR= SCREENSHOTS_DIR= "$fish_bin" -c 'string join "|" $WORKSPACE_DIR $BARBATDEV_DIR $CORTEX_HOME $CORTEX_ROOT $CORTEX_DOTFILES_DIR $CORTEX_MULTIPLEXER $CLAUDE_CODE_EFFORT_LEVEL $WORK_PROJECTS_DIR $PERSONAL_PROJECTS_DIR $INNIT_DIR $SCREENSHOTS_DIR')
assert_equal "$empty_defaults" "$home/dev|$home/dev/barbatdev|$home/.cortex|$home/dev/barbatdev/cortex/cortex|$home/dev/barbatdev/cortex/cortex-dotfiles|cmux|high|$home/dev/barbatdev/innit|$home/dev/barbatdev/products|$home/dev/barbatdev/innit|$home/Screenshots" 'empty environment values use defaults'

printf 'set -gx WORKSPACE_DIR "$HOME/private-dev"\nset -gx EDITOR private-editor\nset -gx VISUAL private-editor\n' >"$xdg/fish/conf.d/99-local.fish"
set -l overrides (run_fish -c 'string join "|" $WORKSPACE_DIR $EDITOR $VISUAL')
assert_equal "$overrides" "$home/private-dev|private-editor|private-editor" '99-local override precedence'

mkdir -p "$home/dev" "$home/dev/barbatdev/innit" "$workspace/apis" "$workspace/mobile" "$workspace/webs" "$workspace/pcsoft" "$workspace/dotfiles"
set -l navigation (run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; set -gx INNIT_APIS_DIR '$workspace/apis'; set -gx INNIT_MOBILE_DIR '$workspace/mobile'; set -gx INNIT_WEBS_DIR '$workspace/webs'; set -gx INNIT_PCSOFT_DIR '$workspace/pcsoft'; set -gx _DOTFILES_DIR '$workspace/dotfiles'; dev; pwd; barbat; pwd; innit; pwd; innit-apis; pwd; innit-mobile; pwd; innit-webs; pwd; innit-pcsoft; pwd; dotfiles; pwd" | string collect)
set -l expected_navigation (printf '%s\n' "$home/dev" "$home/dev/barbatdev" "$home/dev/barbatdev/innit" "$workspace/apis" "$workspace/mobile" "$workspace/webs" "$workspace/pcsoft" "$workspace/dotfiles" | string collect)
assert_equal "$navigation" "$expected_navigation" 'navigation destinations'

set -l fallback (run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; set -gx INNIT_APIS_DIR '$workspace/missing'; innit-apis; pwd")
assert_equal "$fallback" "$home/dev/barbatdev/innit" 'navigation fallback'
assert_navigation_error "set -gx BARBATDEV_DIR '$workspace/missing'; barbat" "$workspace/missing" 'barbat missing directory'

mkdir -p "$workspace/cowork" "$workspace/personal" "$workspace/barbatdev/tools" "$workspace/barbatdev/innit" "$workspace/barbatdev/products" "$home/dev/worktrees"
set -l extended_navigation (run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; set -gx WORK_PROJECTS_DIR '$workspace/cowork'; set -gx PERSONAL_PROJECTS_DIR '$workspace/personal'; set -gx BARBATDEV_DIR '$workspace/barbatdev'; cowork; pwd; personal; pwd; tools; pwd; worktrees; pwd; work; pwd" | string collect)
set -l expected_extended_navigation (printf '%s\n' "$workspace/cowork" "$workspace/personal" "$workspace/barbatdev/tools" "$home/dev/worktrees" "$workspace/cowork" | string collect)
assert_equal "$extended_navigation" "$expected_extended_navigation" 'extended navigation destinations'

set -l extended_fallback (run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; set -gx WORK_PROJECTS_DIR '$workspace/missing-work'; set -gx PERSONAL_PROJECTS_DIR '$workspace/missing-personal'; set -gx BARBATDEV_DIR '$workspace/barbatdev'; cowork; pwd; work; pwd; personal; pwd" | string collect)
set -l expected_extended_fallback (printf '%s\n' "$workspace/barbatdev/innit" "$workspace/barbatdev/innit" "$workspace/barbatdev/products" | string collect)
assert_equal "$extended_fallback" "$expected_extended_fallback" 'extended navigation fallbacks'

assert_navigation_error "set -gx WORK_PROJECTS_DIR '$workspace/missing-work'; set -gx BARBATDEV_DIR '$workspace/missing-barbat'; cowork" "$workspace/missing-work" 'cowork missing directories'
assert_navigation_error "set -gx PERSONAL_PROJECTS_DIR '$workspace/missing-personal'; set -gx BARBATDEV_DIR '$workspace/missing-barbat'; personal" "$workspace/missing-personal" 'personal missing directories'
assert_navigation_error "set -gx BARBATDEV_DIR '$workspace/missing-barbat'; tools" "$workspace/missing-barbat/tools" 'tools missing directory'
assert_navigation_error "set -gx HOME '$workspace/missing-home'; worktrees" "$workspace/missing-home/dev/worktrees" 'worktrees missing directory'
assert_navigation_error "set -gx WORK_PROJECTS_DIR '$workspace/missing-work'; set -gx BARBATDEV_DIR '$workspace/missing-barbat'; work" "$workspace/missing-work" 'work missing directories'

set -l aliases (run_fish -c 'functions gs; functions gpl' | string collect)
string match -q '*git status*' "$aliases"; or fail 'gs alias'
string match -q '*git pull*' "$aliases"; or fail 'gpl alias'

printf '#!/bin/sh\necho Linux\n' >"$bin/uname"
chmod +x "$bin/uname"
set -l linux_open_alias (run_fish -c 'functions -q o; and echo defined; or echo absent')
assert_equal "$linux_open_alias" absent 'Linux Fish startup excludes the macOS open alias'

mkdir -p "$home/.local/bin" "$home/.opencode/bin" "$home/.local/share/mise/shims" "$home/.nix-profile/bin"
printf '#!/bin/sh\n' >"$home/.local/bin/w2-local-command"
chmod +x "$home/.local/bin/w2-local-command"
printf '#!/bin/sh\n' >"$home/.opencode/bin/w2-opencode-command"
chmod +x "$home/.opencode/bin/w2-opencode-command"
printf '#!/bin/sh\n' >"$home/.local/share/mise/shims/w2-mise-command"
chmod +x "$home/.local/share/mise/shims/w2-mise-command"
printf '#!/bin/sh\n' >"$home/.nix-profile/bin/w2-profile-command"
chmod +x "$home/.nix-profile/bin/w2-profile-command"
set -l linux_local_command (run_clean_fish -c "source '$xdg/fish/conf.d/10-core.fish'; command -s w2-local-command")
assert_equal "$linux_local_command" "$home/.local/bin/w2-local-command" 'Linux Fish startup resolves commands from the user-local bin directory'
set -l linux_opencode_command (run_clean_fish -c "source '$xdg/fish/conf.d/10-core.fish'; command -s w2-opencode-command")
assert_equal "$linux_opencode_command" "$home/.opencode/bin/w2-opencode-command" 'Linux Fish startup resolves commands from the OpenCode bin directory'
set -l linux_mise_command (run_clean_fish -c "source '$xdg/fish/conf.d/10-core.fish'; command -s w2-mise-command")
assert_equal "$linux_mise_command" "$home/.local/share/mise/shims/w2-mise-command" 'Linux Fish startup resolves commands from the mise shims directory'
set -l linux_profile_command (run_clean_fish -c "source '$xdg/fish/conf.d/10-core.fish'; command -s w2-profile-command")
assert_equal "$linux_profile_command" "$home/.nix-profile/bin/w2-profile-command" 'Linux Fish startup resolves commands from the user Nix profile'
set -l linux_path (run_clean_fish -c "source '$xdg/fish/conf.d/10-core.fish'; string join '|' \$PATH")
string match -q "$home/.local/bin|$home/.opencode/bin|$home/.local/share/mise/shims|$home/.nix-profile/bin|*" "$linux_path"; or fail 'Linux Fish startup orders portable tool directories before the user Nix profile'

printf '#!/bin/sh\n[ "$1" = init ] && printf "set -gx W2_STARSHIP_READY 1\\n"\n' >"$bin/starship"
chmod +x "$bin/starship"
set -l noninteractive (run_fish -c 'set -q W2_STARSHIP_READY; and echo ready; or echo skipped')
assert_equal "$noninteractive" skipped 'noninteractive Starship guard'
set -l interactive (run_fish -i -c 'set -q W2_STARSHIP_READY; and echo ready; or echo skipped' 2>/dev/null)
assert_equal "$interactive" ready 'interactive Starship initialization'

printf 'PASS: Fish W2 core profile\n'
