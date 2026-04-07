#!/bin/bash
# Claude Code status line (adapted from sebat-duls for Linux)
# Line 1: dir │ branch │ git status │ model │ context
# Line 2: plan usage (5h │ 7d) — when credentials are available

INPUT=$(cat)

# ── Parse CWD (from JSON, fallback to pwd) ──
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[ -z "$CWD" ] && CWD=$(pwd)

# ── Parse model ──
MODEL_ID=$(echo "$INPUT" | jq -r '.model.id // "unknown"')
MODEL_NAME=$(echo "$MODEL_ID" | sed 's/claude-//' | cut -d'-' -f1 | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
MODEL_VER=$(echo "$MODEL_ID" | sed 's/claude-//' | sed 's/^[a-z]*-//' | cut -d'-' -f1,2 | tr '-' '.')
MODEL="$MODEL_NAME $MODEL_VER"

# ── Parse context ──
TOTAL=$(echo "$INPUT" | jq -r '(.context_window.current_usage.input_tokens // 0) + (.context_window.current_usage.output_tokens // 0) + (.context_window.current_usage.cache_creation_input_tokens // 0) + (.context_window.current_usage.cache_read_input_tokens // 0)')
CTX_SIZE=$(echo "$INPUT" | jq -r '.context_window.context_window_size // 200000')

# ══════════════════════════════════════
# LINE 1: status line
# ══════════════════════════════════════

# Directory
echo "$CWD" | sed "s|^$HOME|~|" | awk '{printf "\033[38;5;37m%s\033[0m", $0}'

# Git branch + status
if git -C "$CWD" rev-parse --git-dir > /dev/null 2>&1; then
  printf " \033[90m│\033[0m "
  BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)
  printf "\033[38;5;208m%s\033[0m" "$BRANCH"
  printf " \033[90m│\033[0m "
  changes=$(git -C "$CWD" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$changes" -eq 0 ]; then
    ahead_behind=$(git -C "$CWD" rev-list --left-right --count HEAD...@{u} 2>/dev/null)
    if [ -n "$ahead_behind" ]; then
      ahead=$(echo $ahead_behind | awk '{print $1}')
      behind=$(echo $ahead_behind | awk '{print $2}')
      if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
        printf "\033[38;5;68m↑%s ↓%s\033[0m" "$ahead" "$behind"
      else
        printf "\033[38;5;71m✓ clean\033[0m"
      fi
    else
      printf "\033[38;5;71m✓ clean\033[0m"
    fi
  else
    printf "\033[38;5;179m● %s changes\033[0m" "$changes"
  fi
fi

# Model
printf " \033[90m│\033[0m "
printf "\033[38;5;141m%s\033[0m" "$MODEL"

# Context remaining
printf " \033[90m│\033[0m "
if [ "$TOTAL" -lt "$CTX_SIZE" ]; then
  REMAINING=$((CTX_SIZE - TOTAL))
  PCT=$(((CTX_SIZE - TOTAL) * 100 / CTX_SIZE))
  REMAINING_K=$((REMAINING / 1000))
  if [ "$PCT" -gt 75 ]; then
    printf "\033[38;5;71m%s%% (%sk)\033[0m" "$PCT" "$REMAINING_K"
  elif [ "$PCT" -gt 50 ]; then
    printf "\033[38;5;222m%s%% (%sk)\033[0m" "$PCT" "$REMAINING_K"
  elif [ "$PCT" -gt 25 ]; then
    printf "\033[38;5;208m%s%% (%sk)\033[0m" "$PCT" "$REMAINING_K"
  else
    printf "\033[38;5;167m%s%% (%sk)\033[0m" "$PCT" "$REMAINING_K"
  fi
else
  TOTAL_K=$((TOTAL / 1000))
  printf "\033[38;5;247m%sk tokens\033[0m" "$TOTAL_K"
fi

# ══════════════════════════════════════
# LINE 2: plan usage
# ══════════════════════════════════════

# Parse rate limits directly from the statusline JSON input
FIVE_H=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // empty')
SEVEN_D=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // empty')
FIVE_H_RESET=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.resets_at // empty')
SEVEN_D_RESET=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.resets_at // empty')

usage_color() {
  local pct=$1
  if [ "$pct" -gt 90 ]; then echo "203"
  elif [ "$pct" -gt 70 ]; then echo "208"
  elif [ "$pct" -gt 50 ]; then echo "222"
  else echo "108"; fi
}

local_time() {
  python3 -c "
from datetime import datetime
utc = datetime.fromisoformat('$1')
local_dt = datetime.fromtimestamp(utc.timestamp())
print(local_dt.strftime('%-I:%M %p'))
" 2>/dev/null
}

local_datetime() {
  python3 -c "
from datetime import datetime
utc = datetime.fromisoformat('$1')
local_dt = datetime.fromtimestamp(utc.timestamp())
print(local_dt.strftime('%b %-d, %-I:%M %p'))
" 2>/dev/null
}

SHOW_5H=0; SHOW_7D=0
if [ -n "$FIVE_H" ]; then
  FH=$(printf '%.0f' "$FIVE_H")
  FH_COLOR=$(usage_color "$FH")
  [ "$FH" -ge 80 ] && SHOW_5H=1
fi
if [ -n "$SEVEN_D" ]; then
  SD=$(printf '%.0f' "$SEVEN_D")
  SD_COLOR=$(usage_color "$SD")
  [ "$SD" -ge 90 ] && SHOW_7D=1
fi

if [ -n "$FIVE_H" ] || [ -n "$SEVEN_D" ]; then
  printf "\n"

  if [ -n "$FIVE_H" ]; then
    printf "\033[38;5;%sm5h: %s%%\033[0m" "$FH_COLOR" "$FH"
    if [ "$SHOW_5H" -eq 1 ] && [ -n "$FIVE_H_RESET" ]; then
      FH_LOCAL=$(local_time "$FIVE_H_RESET")
      printf " \033[90m↻ %s\033[0m" "$FH_LOCAL"
    fi
  fi

  if [ -n "$FIVE_H" ] && [ -n "$SEVEN_D" ]; then
    printf " \033[90m·\033[0m "
  fi

  if [ -n "$SEVEN_D" ]; then
    printf "\033[38;5;%sm7d: %s%%\033[0m" "$SD_COLOR" "$SD"
    if [ "$SHOW_7D" -eq 1 ] && [ -n "$SEVEN_D_RESET" ]; then
      SD_LOCAL=$(local_datetime "$SEVEN_D_RESET")
      printf " \033[90m↻ %s\033[0m" "$SD_LOCAL"
    fi
  fi
fi
