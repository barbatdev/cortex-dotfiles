# RefactorIA Fish colors.

set -l base "#0B0714"
set -l panel "#17102A"
set -l text "#FFFFFF"
set -l selection_text "#FFFFFF"
set -l active_violet "#A477FF"
set -l bright_lavender "#C7A6FF"
set -l bright_amber "#FFE08A"
set -l amber "#FFC857"
set -l bright_blue "#8CC8FF"
set -l error "#FF6B8A"
set -l muted "#B8AEC8"
set -l dim "#A39AB5"
set -l selection "#7127FF"
set -l search_background "#2C2144"

# Syntax highlighting colors.
set -g fish_color_normal $text
set -g fish_color_command --bold $active_violet
set -g fish_color_keyword --bold $bright_lavender
set -g fish_color_quote $bright_amber
set -g fish_color_redirection $bright_blue
set -g fish_color_end $amber
set -g fish_color_error --bold $error
set -g fish_color_param $bright_lavender
set -g fish_color_comment $dim
set -g fish_color_selection --background=$selection $selection_text
set -g fish_color_search_match --background=$search_background $selection_text
set -g fish_color_operator $bright_blue
set -g fish_color_escape $active_violet
set -g fish_color_autosuggestion $muted
set -g fish_color_option $bright_lavender

# Completion pager colors.
set -g fish_pager_color_progress $dim
set -g fish_pager_color_prefix --bold $active_violet
set -g fish_pager_color_completion $text
set -g fish_pager_color_description $muted
set -g fish_pager_color_selected_background --background=$selection $selection_text
set -g fish_pager_color_secondary_background --background=$panel
