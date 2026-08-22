function _cortex_run_agent
    set -l target "$argv[1]"
    set -e argv[1]
    set -l original_dir "$PWD"

    cd "$target"; or return 1
    command $argv
    set -l agent_status $status
    cd "$original_dir"; or return 1
    return "$agent_status"
end
