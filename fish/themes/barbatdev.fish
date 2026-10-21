# Barbatdev Fish colors.

set -l base "#0B0B0A"
set -l panel "#171512"
set -l text "#F8F1E7"
set -l selection_text "#FFF7ED"
set -l accent "#F97316"
set -l active_orange "#FB923C"
set -l gold "#FBBF24"
set -l soft_orange "#FDBA74"
set -l bright_blue "#BAE6FD"
set -l error "#EF4444"
set -l muted "#B9AD9C"
set -l dim "#8C8173"
set -l selection "#7A3500"
set -l search_background "#3A1D0C"

# Syntax highlighting colors.
set -g fish_color_normal $text
set -g fish_color_command --bold $accent
set -g fish_color_keyword --bold $active_orange
set -g fish_color_quote $gold
set -g fish_color_redirection $bright_blue
set -g fish_color_end $soft_orange
set -g fish_color_error --bold $error
set -g fish_color_param $soft_orange
set -g fish_color_comment $dim
set -g fish_color_selection --background=$selection $selection_text
set -g fish_color_search_match --background=$search_background $selection_text
set -g fish_color_operator $bright_blue
set -g fish_color_escape $active_orange
set -g fish_color_autosuggestion $muted
set -g fish_color_option $soft_orange

# Completion pager colors.
set -g fish_pager_color_progress $dim
set -g fish_pager_color_prefix --bold $accent
set -g fish_pager_color_completion $text
set -g fish_pager_color_description $muted
set -g fish_pager_color_selected_background --background=$selection $selection_text
set -g fish_pager_color_secondary_background --background=$panel
