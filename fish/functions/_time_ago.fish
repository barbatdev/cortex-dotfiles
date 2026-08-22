function _time_ago
    set -l file "$argv[1]"
    set -l now (command date +%s)
    set -l mtime (command stat -f %m "$file" 2>/dev/null)

    if test $status -ne 0; or test -z "$mtime"
        set mtime "$now"
    end

    set -l difference (math "$now - $mtime")
    if test "$difference" -lt 60
        printf 'justo ahora\n'
    else if test "$difference" -lt 3600
        printf '%sm ago\n' (math "$difference / 60")
    else if test "$difference" -lt 86400
        printf '%sh ago\n' (math "$difference / 3600")
    else
        printf '%sd ago\n' (math "$difference / 86400")
    end
end
