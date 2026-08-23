#!/bin/bash

set -u

input=$(cat)
settings="$HOME/.claude/settings.json"

# ============================================================
# Helpers
# ============================================================

json_get() {
  local filter="$1"
  printf '%s' "$input" | jq -r "$filter // empty" 2>/dev/null
}

setting_get() {
  local filter="$1"

  if [ -f "$settings" ]; then
    jq -r "$filter // empty" "$settings" 2>/dev/null
  fi
}

format_tokens() {
  local n="${1:-0}"

  if [ "$n" -ge 1000000 ]; then
    awk "BEGIN {printf \"%.1fM\", $n / 1000000}"
  elif [ "$n" -ge 1000 ]; then
    awk "BEGIN {printf \"%.0fk\", $n / 1000}"
  else
    printf "%s" "$n"
  fi
}

format_duration() {
  local ms="${1:-0}"
  local total_seconds=$((ms / 1000))
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))

  if [ "$hours" -gt 0 ]; then
    printf '%dh%02dm' "$hours" "$minutes"
  else
    printf '%dm' "$minutes"
  fi
}

# ============================================================
# ANSI
# ============================================================

RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

GRAY='\033[90m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
MAGENTA='\033[35m'

MINIMAX_GREEN='\033[32m'
MINIMAX_YELLOW='\033[33m'
MINIMAX_RED='\033[31m'

# ============================================================
# Model
# ============================================================

model=$(json_get '.model.display_name')
[ -z "$model" ] && model="Claude"

# ============================================================
# Mode
# ============================================================

mode=$(json_get '.mode')

if [ -z "$mode" ]; then
  mode=$(json_get '.permission_mode')
fi

[ -z "$mode" ] && mode="normal"

case "$mode" in
  plan|PLAN)
    mode_display="PLAN"
    mode_color="$CYAN"
    ;;

  acceptEdits|accept-edits|ACCEPT_EDITS)
    mode_display="EDIT"
    mode_color="$GREEN"
    ;;

  bypassPermissions|bypass|BYPASS)
    mode_display="BYPASS"
    mode_color="$RED"
    ;;

  *)
    mode_display=$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')
    mode_color="$MAGENTA"
    ;;
esac

# ============================================================
# Reasoning / Effort
#
# Claude Code 2.1.220:
#
# "effort": {
#   "level": "medium"
# }
# ============================================================

effort=$(json_get '.effort.level')

[ -z "$effort" ] && effort=$(setting_get '.effortLevel')

[ -z "$effort" ] && effort="unknown"

effort=$(printf '%s' "$effort" | tr '[:lower:]' '[:upper:]')

case "$effort" in
  LOW)
    effort_display="LOW"
    effort_color="$GREEN"
    ;;

  MEDIUM)
    effort_display="MED"
    effort_color="$YELLOW"
    ;;

  HIGH)
    effort_display="HIGH"
    effort_color="$RED"
    ;;

  MAX)
    effort_display="MAX"
    effort_color="$RED"
    ;;

  *)
    effort_display="$effort"
    effort_color="$MAGENTA"
    ;;
esac

# ============================================================
# Auto Compact
#
# statusline schema does not expose autoCompactEnabled
# directly in your 2.1.220 payload.
#
# Therefore read settings.json.
# ============================================================

auto_compact=$(setting_get '.autoCompactEnabled')

case "$auto_compact" in
  true)
    compact_display="AUTO"
    compact_color="$GREEN"
    ;;

  false)
    compact_display="OFF"
    compact_color="$RED"
    ;;

  *)
    compact_display="?"
    compact_color="$GRAY"
    ;;
esac

# ============================================================
# Context Window
# ============================================================

used_pct=$(json_get '.context_window.used_percentage')
remaining_pct=$(json_get '.context_window.remaining_percentage')

window_size=$(json_get '.context_window.context_window_size')

[ -z "$window_size" ] && window_size=0

# ============================================================
# Current usage
#
# In your captured payload:
#
# current_usage: null
#
# So do NOT calculate fake usage.
# ============================================================

current_usage_exists=$(printf '%s' "$input" | jq \
  '(.context_window.current_usage != null)' 2>/dev/null)

context_available=false
used_tokens=0

if [ "$current_usage_exists" = "true" ]; then

  input_tokens=$(json_get \
    '.context_window.current_usage.input_tokens')

  output_tokens=$(json_get \
    '.context_window.current_usage.output_tokens')

  cache_creation_tokens=$(json_get \
    '.context_window.current_usage.cache_creation_input_tokens')

  cache_read_tokens=$(json_get \
    '.context_window.current_usage.cache_read_input_tokens')

  [ -z "$input_tokens" ] && input_tokens=0
  [ -z "$output_tokens" ] && output_tokens=0
  [ -z "$cache_creation_tokens" ] && cache_creation_tokens=0
  [ -z "$cache_read_tokens" ] && cache_read_tokens=0

  used_tokens=$(
    awk "BEGIN {
      printf \"%.0f\",
      $input_tokens +
      $output_tokens +
      $cache_creation_tokens +
      $cache_read_tokens
    }"
  )

  context_exact=true
  context_available=true

elif [ -n "$used_pct" ] && [ "$window_size" -gt 0 ]; then

  # current_usage is unavailable.
  # Estimate token usage from Claude Code's percentage.

  used_tokens=$(
    awk "BEGIN {
      printf \"%.0f\",
      $window_size * $used_pct / 100
    }"
  )

  context_exact=false
  context_available=true

else

  context_exact=false
  context_available=false

fi

# ============================================================
# Context Bar
# ============================================================

if [ "$context_available" = "true" ] && [ -n "$used_pct" ]; then

  used_pct=$(printf "%.0f" "$used_pct")

  bar_width=10

  filled=$((used_pct * bar_width / 100))

  if [ "$filled" -gt "$bar_width" ]; then
    filled=$bar_width
  fi

  empty=$((bar_width - filled))

  bar=""

  if [ "$filled" -gt 0 ]; then
    bar=$(printf '%*s' "$filled" '' | tr ' ' '█')
  fi

  if [ "$empty" -gt 0 ]; then
    bar="${bar}$(printf '%*s' "$empty" '' | tr ' ' '░')"
  fi

  if [ "$used_pct" -ge 90 ]; then
    context_color="$RED"
  elif [ "$used_pct" -ge 70 ]; then
    context_color="$YELLOW"
  else
    context_color="$GREEN"
  fi

  used_display=$(format_tokens "$used_tokens")
  window_display=$(format_tokens "$window_size")

  if [ "$context_exact" = "true" ]; then
    context_display="${context_color}${bar} ${used_pct}%${RESET} ${DIM}(${used_display}/${window_display})${RESET}"
  else
    context_display="${context_color}${bar} ${used_pct}%${RESET} ${DIM}(~${used_display}/${window_display})${RESET}"
  fi

else

  context_display="${GRAY}Context: N/A${RESET}"

fi

# ============================================================
# Workspace
# ============================================================

current_dir=$(json_get '.workspace.current_dir')

[ -z "$current_dir" ] && current_dir=$(json_get '.cwd')

[ -z "$current_dir" ] && current_dir=$(pwd)

current_dir="${current_dir/#$HOME/~}"

# ============================================================
# Git
# ============================================================

branch=""

if git_branch=$(git -C "$current_dir" branch \
  --show-current 2>/dev/null); then

  branch="$git_branch"

fi

git_info=""

if [ -n "$branch" ]; then

  if [ -n "$(git -C "$current_dir" status \
    --porcelain 2>/dev/null)" ]; then

    git_info="${branch}*"

  else

    git_info="$branch"

  fi

fi

# ============================================================
# Cost
# ============================================================

cost=$(json_get '.cost.total_cost_usd')

cost_display=""

if [ -n "$cost" ]; then
  cost_display=$(printf '$%.2f' "$cost")
fi

# ============================================================
# Claude Code version
# ============================================================

version=$(json_get '.version')

version_display=""

if [ -n "$version" ]; then
  version_display="v${version}"
fi

# ============================================================
# Thinking
# ============================================================

thinking=$(json_get '.thinking.enabled')

thinking_display=""

if [ "$thinking" = "true" ]; then
  thinking_display="THINK"
fi

# ============================================================
# Fast Mode
# ============================================================

fast_mode=$(json_get '.fast_mode')

fast_display=""

if [ "$fast_mode" = "true" ]; then
  fast_display="FAST"
fi

# ============================================================
# LINE 1
# ============================================================

printf '%b' \
  "${BOLD}◆ ${model}${RESET}" \
  " ${GRAY}│${RESET} " \
  "${mode_color}${BOLD}${mode_display}${RESET}" \
  " ${GRAY}│${RESET} " \
  "${effort_color}${BOLD}REASON:${effort_display}${RESET}" \
  " ${GRAY}│${RESET} " \
  "${compact_color}${BOLD}COMPACT:${compact_display}${RESET}" \
  " ${GRAY}│${RESET} " \
  "$context_display"

# ============================================================
# Optional state indicators
# ============================================================

if [ -n "$thinking_display" ]; then
  printf '%b' \
    " ${GRAY}│${RESET} ${CYAN}${thinking_display}${RESET}"
fi

if [ -n "$fast_display" ]; then
  printf '%b' \
    " ${GRAY}│${RESET} ${MAGENTA}${fast_display}${RESET}"
fi

printf '%b' "\n"

# ============================================================
# LINE 2
# ============================================================

printf '%b' \
  "${DIM}${current_dir}${RESET}"

if [ -n "$git_info" ]; then
  printf '%b' \
    " ${GRAY}│${RESET} ${CYAN}${git_info}${RESET}"
fi

if [ -n "$cost_display" ]; then
  printf '%b' \
    " ${GRAY}│${RESET} ${YELLOW}${cost_display}${RESET}"
fi

if [ -n "$version_display" ]; then
  printf '%b' \
    " ${GRAY}│${RESET} ${DIM}${version_display}${RESET}"
fi