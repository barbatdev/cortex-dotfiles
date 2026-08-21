#!/usr/bin/env fish

set -l repo_root (cd (dirname (dirname (status filename))); and pwd)
set -g functions_dir "$repo_root/functions"
set -g workspace (mktemp -d)
test -n "$workspace"; or exit 1

function _cleanup_workspace --on-event fish_exit
    test -d "$workspace"; and rm -rf -- "$workspace"
end

set -g home "$workspace/home"
set -g bin "$workspace/bin"
set -g repo "$workspace/repo"
set -gx W3_GIT_LOG "$workspace/git.log"
mkdir -p "$home" "$bin" "$repo"

function fail
    printf 'FAIL: %s\n' "$argv" >&2
    exit 1
end

function assert_equal
    test "$argv[1]" = "$argv[2]"; or fail "$argv[3] (expected '$argv[2]', got '$argv[1]')"
end

function run_fish
    env HOME="$home" PATH="$bin:/usr/bin:/bin" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$workspace/global-gitconfig" /opt/homebrew/bin/fish $argv
end

printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$W3_GIT_LOG"\n[ "$1" = clone ] && exit 0\nexec /usr/bin/git "$@"\n' >"$bin/git"
printf '#!/bin/sh\nprintf editor >> "$W3_EDITOR_LOG"\n' >"$bin/editor"
printf '#!/bin/sh\nprintf ssh >> "$W3_SSH_LOG"\nexit 97\n' >"$bin/ssh"
chmod +x "$bin/git" "$bin/editor" "$bin/ssh"

/usr/bin/git -C "$repo" init -q
/usr/bin/git -C "$repo" config user.name Baseline
/usr/bin/git -C "$repo" config user.email baseline@example.invalid
/usr/bin/git -C "$repo" remote add origin git@github.com:org/repo.git
printf 'baseline\n' >"$repo/README.md"
/usr/bin/git -C "$repo" add README.md
/usr/bin/git -C "$repo" commit -q -m baseline

set -l configured (run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; cd '$repo'; set -gx GIT_WORKDEV_NAME Work; set -gx GIT_WORKDEV_EMAIL work@example.invalid; git-workdev >/dev/null; string join '|' (git config --local user.name) (git config --local user.email) (git remote get-url origin)")
assert_equal "$configured" "Work|work@example.invalid|git@github-workdev:org/repo.git" 'work identity and alias routing'

/usr/bin/git -C "$repo" remote set-url origin git@github-work-legacy:org/repo.git
set -l legacy_alias (run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; cd '$repo'; set -gx GIT_WORKDEV_NAME Work; set -gx GIT_WORKDEV_EMAIL work@example.invalid; git-workdev >/dev/null; git remote get-url origin")
assert_equal "$legacy_alias" git@github-workdev:org/repo.git 'legacy work alias routing'

/usr/bin/git -C "$repo" remote set-url origin git@github.com:org/repo.git
set -l personal (run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; cd '$repo'; set -gx GIT_PERSONALDEV_NAME Personal; set -gx GIT_PERSONALDEV_EMAIL personal@example.invalid; git-personaldev >/dev/null; string join '|' (git config --local user.name) (git config --local user.email) (git remote get-url origin)")
assert_equal "$personal" "Personal|personal@example.invalid|git@github-personaldev:org/repo.git" 'personal identity and alias routing'

/usr/bin/git -C "$repo" config --unset-all user.name
/usr/bin/git -C "$repo" config --unset-all user.email
/usr/bin/git -C "$repo" remote set-url origin git@github.com:org/repo.git
run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; cd '$repo'; git-workdev" >/dev/null 2>&1; and fail 'missing private identity must fail'
set -l missing_name (/usr/bin/git -C "$repo" config --local --get user.name)
test -z "$missing_name"; or fail 'missing identity changed local name'
set -l unchanged_remote (/usr/bin/git -C "$repo" remote get-url origin)
assert_equal "$unchanged_remote" git@github.com:org/repo.git 'missing identity changed remote'

set -l whoami (run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; cd '$repo'; git-whoami")
string match -q '*nombre : no configurado*' "$whoami"; or fail 'git-whoami name fallback'
string match -q '*remote : git@github.com:org/repo.git*' "$whoami"; or fail 'git-whoami remote'

run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; clone-workdev https://github.com/org/work.git; clone-personaldev git@github.com:org/personal.git"
set -l git_log (cat "$workspace/git.log")
string match -q '*clone git@github-workdev:org/work.git*' "$git_log"; or fail "work clone alias: $git_log"
string match -q '*clone git@github-personaldev:org/personal.git*' "$git_log"; or fail 'personal clone alias'

set -gx W3_EDITOR_LOG "$workspace/editor.log"
run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; is-pcsoft-forbidden FILE.WDP"; or fail 'forbidden extension decision'
run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; is-pcsoft-editable window.WDW"; or fail 'editable extension decision'
run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; is-pcsoft-forbidden window.WDW"; and fail 'editable must not be forbidden'
run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; set -gx EDITOR editor; edit '$workspace/file.wdp'" >/dev/null 2>&1; and fail 'forbidden edit must fail'
test ! -e "$workspace/editor.log"; or fail 'forbidden edit invoked editor'
printf 'n\n' | run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; set -gx EDITOR editor; edit '$workspace/file.wdw'" >/dev/null
test ! -e "$workspace/editor.log"; or fail 'declined editable edit invoked editor'
printf 's\n' | run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; set -gx EDITOR editor; edit '$workspace/file.wdw'" >/dev/null
cat "$workspace/editor.log" | grep -qx editor; or fail 'confirmed editable edit'

printf '' >"$workspace/git.log"
set -l worktree_path "$home/dev/worktrees/repo/w3"
set -l wtadd_output (run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; set -gx CORTEX_MULTIPLEXER none; cd '$repo'; wtadd w3")
string match -q "*Worktree created: $worktree_path*" "$wtadd_output"; or fail "worktree add output: $wtadd_output"
test -e "$worktree_path/.git"; or fail 'worktree add did not create a linked worktree'
set -l canonical_worktree_path (cd "$worktree_path"; and pwd -P)
/usr/bin/git -C "$repo" show-ref --verify --quiet refs/heads/w3; or fail 'worktree branch was not created'
set -l worktree_list (/usr/bin/git -C "$repo" worktree list --porcelain | string collect)
string match -q "*worktree $canonical_worktree_path*" "$worktree_list"; or fail 'worktree add missing from porcelain list'
string match -q '*branch refs/heads/w3*' "$worktree_list"; or fail 'worktree branch missing from porcelain list'

set -l wtlist_output (run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; cd '$repo'; wtlist" | string collect)
string match -q "*$canonical_worktree_path*" "$wtlist_output"; or fail 'wtlist missing linked worktree'
set -l worktree_log (string collect <"$workspace/git.log")
string match -q "*worktree add -b w3 $worktree_path*" "$worktree_log"; or fail 'git wrapper missing worktree add command'
string match -q '*worktree list*' "$worktree_log"; or fail 'git wrapper missing worktree list command'

set -l wtremove_output (run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; cd '$repo'; wtremove w3")
assert_equal "$wtremove_output" "Worktree removed: $worktree_path" 'worktree remove output'
test ! -e "$worktree_path"; or fail 'worktree remove left linked path'
/usr/bin/git -C "$repo" show-ref --verify --quiet refs/heads/w3; or fail 'worktree remove deleted branch'
set -l worktree_list_after (/usr/bin/git -C "$repo" worktree list --porcelain | string collect)
string match -q "*worktree $canonical_worktree_path*" "$worktree_list_after"; and fail 'worktree remove left porcelain entry'
set worktree_log (string collect <"$workspace/git.log")
string match -q "*worktree remove $worktree_path*" "$worktree_log"; or fail 'git wrapper missing worktree remove command'
string match -q '*worktree prune*' "$worktree_log"; or fail 'git wrapper missing worktree prune command'

printf 'tracked\n' >"$repo/project.wdp"
/usr/bin/git -C "$repo" add project.wdp
run_fish -c "set -gx fish_function_path '$functions_dir' \$fish_function_path; cd '$repo'; wtadd blocked" >/dev/null 2>&1; and fail 'PCSoft worktree guard must fail'
test ! -e "$home/dev/worktrees/repo/blocked"; or fail 'PCSoft guard created worktree path'
test ! -e "$workspace/ssh.log"; or fail 'test invoked SSH'

printf 'PASS: Fish W3 helpers\n'
