# Automatic Herdr tab rename: labels the current tab with the repo name
# whenever the directory changes. Fires only inside a Herdr pane (HERDR_ENV=1)
# and only when the label changed, so common shells stay identifiable without
# hitting the API on every prompt. Name comes from the origin URL (same rule
# as gs); falls back to the git toplevel or the directory basename. gs later
# overwrites the tab with the full "repo - pr/is #N" label after creating the
# worktree, so the two mechanisms compose instead of fighting.
function __herdr_tab_autoname_on_pwd --on-event variable:PWD --description 'Rename Herdr tab to the current repo'
    test "$HERDR_ENV" = 1; or return 0
    command -q herdr; or return 0
    set -l name
    if set -l url (git -C "$PWD" remote get-url origin 2>/dev/null)
        set name (basename "$url" | string replace -r '\.git$' '')
    else if set -l root (git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)
        set name (basename "$root")
    else
        set name (basename "$PWD")
    end
    test "$name" != "$_herdr_tab_last_label"; or return 0
    set -g _herdr_tab_last_label $name
    herdr tab rename "$HERDR_TAB_ID" "$name" >/dev/null 2>&1; or return 0
end
