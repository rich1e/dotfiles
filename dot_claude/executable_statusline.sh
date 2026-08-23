#!/bin/bash

set -u

input=$(cat)
settings="$HOME/.claude/settings.json"

# ============================================================
# Minimax Code Plan
#
# Source user shell extension so shell functions like
# `minimax_api_key` (which reads from macOS keychain via
# getBase64Key) are available in this non-interactive shell.
# ============================================================

minimax_api_key_value="${MINIMAX_API_KEY:-}"

# If MINIMAX_API_KEY was injected by sourcing zsh-extend.sh but the file
# wasn't rendered by chezmoi, the literal template `{{ keyring ... }}` ends
# up in the env. That's not a real key — fall back to keychain instead of
# sending a 126-byte template string as Authorization.
if [ -n "$minimax_api_key_value" ] \
  && printf '%s' "$minimax_api_key_value" | grep -q "{{"; then
  minimax_api_key_value=""
fi

if [ -z "$minimax_api_key_value" ]; then
  # DO NOT `source $HOME/zsh-extend.sh` — it pollutes stdout of subsequent
  # commands (e.g. `security find-generic-password`) with status banners
  # like "✅ Android SDK: ..." and inflates the captured "key" to 252
  # bytes, breaking the Authorization header.
  # The `getBase64Key` function is trivial — inline it here.
  raw=$(security find-generic-password -w \
    -s "minimax-api-key" -a "$USER" 2>/dev/null || true)

  if [ -n "$raw" ]; then
    raw="${raw#go-keyring-base64:}"
    minimax_api_key_value=$(printf '%s' "$raw" | base64 -d 2>/dev/null || true)
  fi
fi

# Strip any trailing whitespace — base64 -d on macOS may append \n
minimax_api_key_value="${minimax_api_key_value%%[[:space:]]}"
minimax_api_key_value="${minimax_api_key_value##[[:space:]]}"

minimax_cache_dir="$HOME/.claude/cache/minimax"
mkdir -p "$minimax_cache_dir" 2>/dev/null || true
minimax_cache_file="$minimax_cache_dir/usage.json"
minimax_cache_ttl=60  # seconds — statusline re-renders very often

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
# Minimax usage bar (10-char)
# ============================================================

minimax_bar() {
  local pct="${1:-0}"
  local bar_width=10
  local filled=$((pct * bar_width / 100))

  if [ "$filled" -gt "$bar_width" ]; then filled=$bar_width; fi
  if [ "$filled" -lt 0 ]; then filled=0; fi
  local empty=$((bar_width - filled))

  local bar=""
  if [ "$filled" -gt 0 ]; then
    bar=$(printf '%*s' "$filled" '' | tr ' ' '█')
  fi
  if [ "$empty" -gt 0 ]; then
    bar="${bar}$(printf '%*s' "$empty" '' | tr ' ' '░')"
  fi
  printf '%s' "$bar"
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

# ============================================================
# LINE 3 — Minimax Code Plan
#
# API: POST https://www.minimaxi.com/v1/token_plan/remains
# Returns model_remains[] with general/video entries.
# We render the "general" entry (5h quota + weekly quota).
# ============================================================

minimax_payload=""

if [ -n "$minimax_api_key_value" ]; then

  # Use cache if fresh
  if [ -f "$minimax_cache_file" ]; then
    cache_age=$(( $(date +%s) - $(stat -f %m "$minimax_cache_file" 2>/dev/null || echo 0) ))
    if [ "$cache_age" -lt "$minimax_cache_ttl" ]; then
      minimax_payload=$(cat "$minimax_cache_file" 2>/dev/null)
    fi
  fi

  # Refresh if cache stale or empty
  if [ -z "$minimax_payload" ]; then
    minimax_payload=$(curl -sS --max-time 5 \
      --location 'https://www.minimaxi.com/v1/token_plan/remains' \
      --header "Authorization: Bearer ${minimax_api_key_value}" \
      --header 'Content-Type: application/json' \
      2>/dev/null || true)

    # Only cache successful responses (status_code 0). Don't poison the
    # cache with 1004/401 errors — otherwise an outage sticks for 60s.
    if [ -n "$minimax_payload" ] \
      && [ "$(printf '%s' "$minimax_payload" | jq -r '.base_resp.status_code // 1' 2>/dev/null)" = "0" ]; then
      printf '%s' "$minimax_payload" > "$minimax_cache_file" 2>/dev/null || true
    fi
  fi

fi

# Parse "general" entry
minimax_general=$(printf '%s' "$minimax_payload" | jq -c \
  '.model_remains[]? | select(.model_name == "general")' 2>/dev/null || true)

if [ -n "$minimax_general" ] && [ "$minimax_general" != "null" ]; then

  five_h_remaining=$(printf '%s' "$minimax_general" | jq -r '.current_interval_remaining_percent // empty')
  five_h_reset_ms=$(printf '%s' "$minimax_general"  | jq -r '.remains_time // empty')
  week_remaining=$(printf '%s' "$minimax_general"   | jq -r '.current_weekly_remaining_percent // empty')
  week_reset_ms=$(printf '%s' "$minimax_general"    | jq -r '.weekly_remains_time // empty')

  # remaining_percent is "remaining" → invert to "used"
  five_h_used=$(( 100 - ${five_h_remaining:-0} ))
  week_used=$(( 100 - ${week_remaining:-0} ))

  if [ "$five_h_used" -lt 0 ]; then five_h_used=0; fi
  if [ "$five_h_used" -gt 100 ]; then five_h_used=100; fi
  if [ "$week_used" -lt 0 ]; then week_used=0; fi
  if [ "$week_used" -gt 100 ]; then week_used=100; fi

  bar=$(minimax_bar "$five_h_used")

  if [ "$five_h_used" -ge 90 ]; then
    five_h_color="$RED"
  elif [ "$five_h_used" -ge 70 ]; then
    five_h_color="$YELLOW"
  else
    five_h_color="$GREEN"
  fi

  if [ "$week_used" -ge 90 ]; then
    week_color="$RED"
  elif [ "$week_used" -ge 70 ]; then
    week_color="$YELLOW"
  else
    week_color="$GREEN"
  fi

  reset_display=$(format_duration "${five_h_reset_ms:-0}")
  week_reset_display=$(format_duration "${week_reset_ms:-0}")

  printf '%b' \
    "\n" \
    "${BOLD}MINIMAX${RESET}" \
    " ${GRAY}│${RESET} " \
    "${five_h_color}${five_h_used}% ${bar}${RESET}" \
    " ${GRAY}│${RESET} " \
    "${week_color}${BOLD}WEEK ${week_used}%${RESET}" \
    " ${GRAY}│${RESET} " \
    "${CYAN}5h RESET: ${reset_display}${RESET}"

  if [ -n "$week_reset_ms" ] && [ "$week_reset_ms" != "0" ]; then
    printf '%b' \
      " ${GRAY}│${RESET} " \
      "${CYAN}WEEK RESET: ${week_reset_display}${RESET}"
  fi

else
  printf '%b' \
    "\n" \
    "${DIM}MINIMAX │ unavailable${RESET}"
fi