# Usage: cc [path]
function cc
    set -l resolved (_cortex_resolve_target "$argv[1]"); or return 1
    _cortex_run_agent "$resolved" claude --dangerously-skip-permissions
end
