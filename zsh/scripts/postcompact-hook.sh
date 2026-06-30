#!/usr/bin/env bash
# Hook PostCompact: instruye recargar reglas y contexto después de compactación.

_detect_project() {
    local remote
    remote=$(git remote get-url origin 2>/dev/null)
    if [ -n "$remote" ]; then
        basename "$remote" .git
        return
    fi
    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$git_root" ]; then
        basename "$git_root"
        return
    fi
    basename "$PWD"
}

PROJECT=$(_detect_project)

printf '%s\n' "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PostCompact\",
    \"additionalContext\": \"Contexto compactado. Llamar mem_context() en work-brain para recargar reglas activas y contexto del proyecto: ${PROJECT}.\"
  }
}"
