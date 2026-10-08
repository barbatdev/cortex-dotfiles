# Usage: fish_greeting — show the interactive Fish welcome banner.
function fish_greeting
    # Presentation roles: success #58E6A8, info #8CC8FF, violet #A477FF, secondary #EBEBEB.
    set -l success (set_color --bold '#58E6A8')
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

    set -l title 'Dev Environment'
    set -l status_text '⚡ Fish listo'
    set -l clock (date '+%H:%M:%S')

    printf '\n'

    if test "$terminal_width" -lt 28
        printf '%s%s%s\n' "$violet" "$title" "$reset"
        printf '%s%s%s\n' "$success" "$status_text" "$reset"
        printf '%s%s%s\n' "$info" "🕐 $clock" "$reset"
        printf '%sEscribí%s\n' "$secondary" "$reset"
        printf '  %shelp-profile%s\n' "$violet" "$reset"
        if test "$terminal_width" -ge 17
            printf '%spara ver comandos%s\n' "$secondary" "$reset"
            printf '%sdisponibles%s\n' "$secondary" "$reset"
        else
            printf '%spara%s\n' "$secondary" "$reset"
            printf '%sver%s\n' "$secondary" "$reset"
            printf '%scomandos%s\n' "$secondary" "$reset"
            printf '%sdisponibles%s\n' "$secondary" "$reset"
        end
        printf '\n'
        return 0
    end

    set -l frame_width 40
    if test "$terminal_width" -lt 44
        set frame_width (math "$terminal_width - 4")
    end
    set -l content_width (math "$frame_width - 2")
    set -l rule (string repeat -n (math "$frame_width - 2") '═')

    set -l title_length (string length --visible -- "$title")
    set -l title_left (math "floor(($content_width - $title_length) / 2)")
    test "$title_left" -gt 0; or set title_left 1
    set -l title_right (math "$content_width - $title_length - $title_left")

    set -l status_length (string length --visible -- "$status_text")
    set -l status_left (math "floor(($content_width - $status_length) / 2)")
    test "$status_left" -gt 0; or set status_left 1
    set -l status_right (math "$content_width - $status_length - $status_left")

    set -l clock_text "🕐 $clock"
    set -l clock_length (string length --visible -- "$clock_text")
    set -l clock_left (math "floor(($content_width - $clock_length) / 2)")
    test "$clock_left" -gt 0; or set clock_left 1
    set -l clock_right (math "$content_width - $clock_length - $clock_left")

    printf '%s  ╔%s╗%s\n' "$secondary" "$rule" "$reset"
    printf '%s  ║%s%s%s%s%s%s║%s\n' \
        "$secondary" \
        (string repeat -n "$title_left" ' ') \
        "$violet" "$title" "$reset" \
        (string repeat -n "$title_right" ' ') \
        "$secondary" "$reset"
    printf '%s  ╠%s╣%s\n' "$secondary" "$rule" "$reset"
    printf '%s  ║%s%s%s%s%s%s║%s\n' \
        "$secondary" \
        (string repeat -n "$status_left" ' ') \
        "$success" "$status_text" "$reset" \
        (string repeat -n "$status_right" ' ') \
        "$secondary" "$reset"
    printf '%s  ║%s%s%s%s%s%s║%s\n' \
        "$secondary" \
        (string repeat -n "$clock_left" ' ') \
        "$info" "$clock_text" "$reset" \
        (string repeat -n "$clock_right" ' ') \
        "$secondary" "$reset"
    printf '%s  ╚%s╝%s\n' "$secondary" "$rule" "$reset"
    printf '\n'

    if test "$terminal_width" -ge 58
        printf '  %sEscribí%s %shelp-profile%s %spara ver comandos disponibles%s\n' \
            "$secondary" "$reset" "$violet" "$reset" "$secondary" "$reset"
    else if test "$terminal_width" -ge 40
        printf '  %sEscribí%s %shelp-profile%s\n' "$secondary" "$reset" "$violet" "$reset"
        printf '  %spara ver comandos disponibles%s\n' "$secondary" "$reset"
    else
        printf '  %sEscribí%s\n' "$secondary" "$reset"
        printf '  %shelp-profile%s\n' "$violet" "$reset"
        if test "$terminal_width" -ge 31
            printf '  %spara ver comandos disponibles%s\n' "$secondary" "$reset"
        else if test "$terminal_width" -ge 19
            printf '  %spara ver comandos%s\n' "$secondary" "$reset"
            printf '  %sdisponibles%s\n' "$secondary" "$reset"
        else
            printf '  %spara%s\n' "$secondary" "$reset"
            printf '  %sver%s\n' "$secondary" "$reset"
            printf '  %scomandos%s\n' "$secondary" "$reset"
            printf '  %sdisponibles%s\n' "$secondary" "$reset"
        end
    end
    printf '\n'
end
