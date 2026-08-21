# Usage: oc [path]
function oc
    set -l resolved (_cortex_resolve_target "$argv[1]"); or return 1
    set -l flags
    if set -q OPENCODE_DEFAULT_FLAGS; and test -n "$OPENCODE_DEFAULT_FLAGS"
        set flags (string replace -ra '[[:space:]]+' \n -- "$OPENCODE_DEFAULT_FLAGS")
    end
    _cortex_run_agent "$resolved" opencode $flags
end
