# Herdr terminals (started by herdr-core, marked by HC_TERMINAL_ID) are watched
# from another machine's Herdr window. herdr-core hands them this host's desktop
# (DISPLAY, WAYLAND_DISPLAY) when it has one, so programs like Pi copy into this
# host's clipboard and never send OSC 52 to the viewing machine. Drop the
# desktop for those shells only; other shells on the host keep it.
if set -q HC_TERMINAL_ID; and not set -q SSH_CONNECTION
    set -e DISPLAY
    set -e WAYLAND_DISPLAY
end
