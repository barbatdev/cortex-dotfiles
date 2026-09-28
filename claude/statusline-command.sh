#!/bin/bash
# Minimal, low-color Claude Code statusline.
#
# Segments (left -> right, most -> least important):
#   1. context window usage — ASCII bar + % (bold; red accent only when high)
#   2. model in use (display_name), with reasoning effort level appended
#      when the payload reports one (".effort.level" is only present for
#      models that support reasoning effort — it is never fabricated here)
#   3. cwd, short (basename only)
#   4. git branch, with a single "*" marker if the worktree is dirty
#      (no ahead/behind, staged/modified/untracked counts — judged noise
#      and dropped in favor of a minimal "has changes" cue)
#   5. 5h rate-limit usage (Claude.ai subscription window), when available —
#      the one added datum that changes throughout the day and isn't
#      redundant with the per-conversation context percentage
#
# No per-segment color theme (Starship-palette replication stays dropped).
# Secondary text uses an explicit gray (not ANSI "dim", which is close to
# unreadable in many terminals). Red accent is reserved for context usage
# only, applied consistently to both the bar and the number.

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
model_name=$(echo "$input" | jq -r '.model.display_name // .model.id // empty')
effort_level=$(echo "$input" | jq -r '.effort.level // empty')

bold="\033[1m"
gray="\033[38;2;235;235;235m"
accent="\033[1;38;2;255;107;138m"
reset="\033[0m"
bar_width=8

parts=()

# --- 1. context used: ASCII bar + % ---
if [ -n "$used_pct" ]; then
  pct_int=$(printf '%.0f' "$used_pct")
  filled=$(( (pct_int * bar_width + 50) / 100 ))
  [ "$filled" -gt "$bar_width" ] && filled=$bar_width
  empty=$(( bar_width - filled ))

  if [ "$pct_int" -ge 80 ]; then
    fill_color="$accent"
  else
    fill_color="$bold"
  fi

  filled_str=$(printf '%*s' "$filled" '')
  filled_str=${filled_str// /█}
  empty_str=$(printf '%*s' "$empty" '')
  empty_str=${empty_str// /░}
  bar="${gray}[${reset}${fill_color}${filled_str}${reset}${gray}${empty_str}]${reset}"

  parts+=("${bar} ${fill_color}${pct_int}% ctx${reset}")
else
  empty_str=$(printf '%*s' "$bar_width" '')
  empty_str=${empty_str// /░}
  parts+=("${gray}[${empty_str}] ctx --${reset}")
fi

# --- 2. model in use (+ reasoning effort, only when the payload reports it) ---
if [ -n "$model_name" ]; then
  if [ -n "$effort_level" ]; then
    parts+=("${gray}${model_name} (${effort_level})${reset}")
  else
    parts+=("${gray}${model_name}${reset}")
  fi
fi

# --- 3. directory, short ---
parts+=("${gray}$(basename "$cwd")${reset}")

# --- 4. git branch (+ minimal dirty marker), --no-optional-locks ---
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    dirty=""
    if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
      dirty="*"
    fi
    parts+=("${gray}${branch}${dirty}${reset}")
  fi
fi

# --- 5. 5h rate-limit usage, when the field is present ---
if [ -n "$five_hour_pct" ]; then
  five_hour_int=$(printf '%.0f' "$five_hour_pct")
  parts+=("${gray}5h ${five_hour_int}%${reset}")
fi

out=""
for i in "${!parts[@]}"; do
  [ "$i" -gt 0 ] && out="${out} ${gray}·${reset} "
  out="${out}${parts[$i]}"
done

printf "%b" "$out"
