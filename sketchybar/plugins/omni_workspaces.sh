#!/bin/bash
# Start or refresh the OmniWM workspace listener (launchd agent) from sketchybarrc.
# Only touches its own label: bootstraps it when missing, otherwise kickstart -k
# so the reloaded bar receives a fresh initial snapshot. Never kills other processes.

LABEL="com.cortex.omniwm-workspaces"
PLIST="${OMNI_WS_PLIST:-$HOME/Library/LaunchAgents/$LABEL.plist}"
DOMAIN="gui/$(id -u)"

if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
    launchctl kickstart -k "$DOMAIN/$LABEL"
elif [ -f "$PLIST" ]; then
    launchctl bootstrap "$DOMAIN" "$PLIST"
else
    echo "omni_workspaces: $PLIST not installed; see sketchybar/README.md" >&2
fi
exit 0
