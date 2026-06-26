#!/bin/bash

case "$(date '+%u')" in
    1) day="lun" ;;
    2) day="mar" ;;
    3) day="mié" ;;
    4) day="jue" ;;
    5) day="vie" ;;
    6) day="sáb" ;;
    7) day="dom" ;;
esac

case "$(date '+%-m')" in
    1) month="ene" ;;
    2) month="feb" ;;
    3) month="mar" ;;
    4) month="abr" ;;
    5) month="may" ;;
    6) month="jun" ;;
    7) month="jul" ;;
    8) month="ago" ;;
    9) month="sep" ;;
    10) month="oct" ;;
    11) month="nov" ;;
    12) month="dic" ;;
esac

sketchybar --set "$NAME" label="$day $(date '+%-d') $month  $(date '+%H:%M')"
