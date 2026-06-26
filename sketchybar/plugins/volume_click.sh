#!/bin/bash

muted=$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)

if [[ "$muted" == "true" ]]; then
    osascript -e 'set volume without output muted' >/dev/null 2>&1
else
    osascript -e 'set volume with output muted' >/dev/null 2>&1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
"$script_dir/volume.sh"
