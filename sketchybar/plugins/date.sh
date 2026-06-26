#!/bin/bash

sketchybar --set "$NAME" label="$(LC_TIME=C date '+%a %d %b  %H:%M')"
