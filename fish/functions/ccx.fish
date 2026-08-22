# Usage: ccx <context> [path]
function ccx
    set -l context "$argv[1]"
    if test -z "$context"
        printf 'Uso: ccx <contexto> [directorio]\n' >&2
        return 1
    end

    set -l resolved (_cortex_resolve_target "$argv[2]"); or return 1
    begin
        printf '%s\n' "$context" | _cortex_run_agent "$resolved" claude
        return $pipestatus[-1]
    end
end
