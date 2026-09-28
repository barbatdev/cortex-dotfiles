# Usage: help-profile — show the confirmed Fish helper commands.
function help-profile
    # Presentation roles: info #8CC8FF, violet #A477FF, secondary #EBEBEB, reset normal.
    set -l info (set_color --bold '#8CC8FF')
    set -l violet (set_color --bold '#A477FF')
    set -l secondary (set_color '#EBEBEB')
    set -l reset (set_color normal)

    set -l terminal_width 80
    if set -q COLUMNS
        set -l candidate "$COLUMNS"
        if string match -qr '^[1-9][0-9]*$' -- "$candidate"
            set terminal_width "$candidate"
        end
    else if command -q tput
        set -l detected_width (tput cols 2>/dev/null)
        if string match -qr '^[1-9][0-9]*$' -- "$detected_width"
            set terminal_width "$detected_width"
        end
    end

    set -l heading_rule ''
    set -l heading_indent '  '
    if test "$terminal_width" -ge 26
        set -l rule_width 41
        if test "$terminal_width" -lt 45
            set heading_indent ''
            set rule_width (math "$terminal_width - 2")
        end
        set heading_rule (string repeat -n "$rule_width" '━')
    end

    printf '\n'
    if test "$terminal_width" -lt 26
        printf '%sFish%s\n' "$violet" "$reset"
        if test "$terminal_width" -ge 19
            printf '%s— Referencia rápida%s\n' "$violet" "$reset"
        else
            printf '%s— Referencia%s\n' "$violet" "$reset"
            printf '%srápida%s\n' "$violet" "$reset"
        end
    else
        printf '%s%s%s\n' "$violet" "$heading_rule" "$reset"
        printf '%s%sFish — Referencia rápida%s\n' "$violet" "$heading_indent" "$reset"
        printf '%s%s%s\n' "$violet" "$heading_rule" "$reset"
    end

    printf '\n%sGit identidades%s\n' "$violet" "$reset"
    _help_profile_print_entries "$info" "$secondary" "$reset" "$terminal_width" \
        git-workdev 'Setear identidad de trabajo en repo actual' \
        git-personaldev 'Setear identidad personal en repo actual' \
        git-whoami 'Ver identidad y remote configurados' \
        clone-workdev 'Clonar repo de cuenta de trabajo' \
        clone-personaldev 'Clonar repo de cuenta personal'

    printf '\n%sNavegación%s\n' "$violet" "$reset"
    _help_profile_print_entries "$info" "$secondary" "$reset" "$terminal_width" \
        dev 'Ir al workspace de desarrollo' \
        barbat 'Ir al workspace de Barbatdev' \
        cowork 'Ir a los proyectos de trabajo compartidos' \
        personal 'Ir a los proyectos personales' \
        tools 'Ir al directorio de herramientas' \
        worktrees 'Ir a los worktrees de desarrollo' \
        work 'Ir a los proyectos de trabajo' \
        innit 'Ir al workspace de InnIT' \
        innit-apis 'Ir al área de APIs de InnIT o alternativa' \
        innit-mobile 'Ir al área mobile de InnIT o alternativa' \
        innit-webs 'Ir al área web de InnIT o alternativa' \
        innit-pcsoft 'Ir al área PCSoft de InnIT o alternativa' \
        dotfiles 'Ir a este repositorio de dotfiles'

    if test "$terminal_width" -ge 17
        printf '\n%sClaude / OpenCode%s\n' "$violet" "$reset"
    else
        printf '\n%sClaude /%s\n' "$violet" "$reset"
        printf '%sOpenCode%s\n' "$violet" "$reset"
    end
    _help_profile_print_entries "$info" "$secondary" "$reset" "$terminal_width" \
        'cc [path]' 'Abrir Claude Code en un directorio' \
        'ccx <context> [path]' 'Abrir Claude Code con contexto inicial' \
        'ccd [subpath]' 'Ir al workspace de Claude' \
        'ccclip <file...>' 'Copiar archivos como contexto Markdown' \
        'oc [path]' 'Abrir OpenCode en un directorio' \
        'ocb [path]' 'Abrir OpenCode mediante el helper de Fish' \
        herdr-orient 'Ver contexto de host, repo, SSH y Herdr'

    printf '\n'
end

# Private renderer for command/description pairs; it wraps descriptions on narrow terminals.
function _help_profile_print_entries
    set -l info $argv[1]
    set -l secondary $argv[2]
    set -l reset $argv[3]
    set -l terminal_width $argv[4]
    set -l entries $argv[5..-1]
    set -l description_width (math "$terminal_width - 6")
    test "$description_width" -gt 1; or set description_width 1

    set -l index 1
    set -l entry_count (count $entries)
    while test "$index" -lt "$entry_count"
        set -l command $entries[$index]
        set -l description $entries[(math "$index + 1")]
        set -l command_name (string match -r '^[^[:space:]]+' -- "$command")
        if not type -q "$command_name"
            set index (math "$index + 2")
            continue
        end
        if test "$terminal_width" -ge 72
            printf '  %s%-22s%s %s%s%s\n' "$info" "$command" "$reset" "$secondary" "$description" "$reset"
        else
            _help_profile_print_command "$info" "$reset" "$terminal_width" "$command"
            set -l line ''
            for word in (string split ' ' -- "$description")
                if test -z "$line"
                    set line "$word"
                else
                    set -l candidate "$line $word"
                    if test (string length -- "$candidate") -le "$description_width"
                        set line "$candidate"
                    else
                        printf '    %s%s%s\n' "$secondary" "$line" "$reset"
                        set line "$word"
                    end
                end
            end
            test -z "$line"; or printf '    %s%s%s\n' "$secondary" "$line" "$reset"
        end
        set index (math "$index + 2")
    end
end

# Private renderer for command signatures; it wraps at token and hyphen boundaries.
function _help_profile_print_command
    set -l info $argv[1]
    set -l reset $argv[2]
    set -l terminal_width $argv[3]
    set -l command $argv[4]
    set -l command_length (string length --visible -- "$command")

    if test (math "$command_length + 2") -le "$terminal_width"
        printf '  %s%s%s\n' "$info" "$command" "$reset"
        return 0
    end

    set -l line ''
    set -l indent '  '
    set -l continuation_indent '    '
    set -l chunk_width (math "$terminal_width - 4")
    test "$chunk_width" -gt 0; or set chunk_width 1

    for token in (string split ' ' -- "$command")
        set -l indent_width (string length --visible -- "$indent")
        set -l line_length (string length --visible -- "$line")
        set -l token_length (string length --visible -- "$token")
        set -l separator_width 0
        test -z "$line"; or set separator_width 1

        if test (math "$indent_width + $line_length + $separator_width + $token_length") -le "$terminal_width"
            if test -n "$line"
                set line "$line $token"
            else
                set line "$token"
            end
            continue
        end

        if test -n "$line"
            printf '%s%s%s%s\n' "$indent" "$info" "$line" "$reset"
            set line ''
            set indent "$continuation_indent"
        end

        set indent_width (string length --visible -- "$indent")
        set token_length (string length --visible -- "$token")
        if test (math "$indent_width + $token_length") -le "$terminal_width"
            set line "$token"
            continue
        end

        set -l token_chunks
        set -l hyphen_parts (string split '-' -- "$token")
        if test (count $hyphen_parts) -gt 1
            set -l part_index 1
            set -l part_count (count $hyphen_parts)
            for part in $hyphen_parts
                if test "$part_index" -lt "$part_count"
                    set -a token_chunks "$part-"
                else
                    set -a token_chunks "$part"
                end
                set part_index (math "$part_index + 1")
            end
        else
            set token_chunks "$token"
        end

        set -l safe_chunks
        for chunk in $token_chunks
            set -l remaining "$chunk"
            while test (string length --visible -- "$remaining") -gt "$chunk_width"
                set -a safe_chunks (string sub -l "$chunk_width" -- "$remaining")
                set remaining (string sub -s (math "$chunk_width + 1") -- "$remaining")
            end
            set -a safe_chunks "$remaining"
        end

        set -l chunk_index 1
        set -l chunk_count (count $safe_chunks)
        for chunk in $safe_chunks
            if test "$chunk_index" -lt "$chunk_count"
                printf '%s%s%s%s\n' "$indent" "$info" "$chunk" "$reset"
                set indent "$continuation_indent"
            else
                set line "$chunk"
                set indent "$continuation_indent"
            end
            set chunk_index (math "$chunk_index + 1")
        end
    end

    test -z "$line"; or printf '%s%s%s%s\n' "$indent" "$info" "$line" "$reset"
end
