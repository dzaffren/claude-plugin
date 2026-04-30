#!/bin/bash
# forge statusline — two-line status bar for Claude Code.
# Line 1: <model> | <tokens> | <cost> | ctx:[bar] <%>
# Line 2: <cwd with ~> (<git branch>)
#
# Colors (ANSI):
#   cyan bold  = model
#   yellow     = tokens
#   green      = cost
#   ctx bar/pct: green <40%, orange 40-60%, red >=60%
#   blue       = cwd
#   yellow bold= branch
#   dim        = separators and empty bar cells

set -eu

INPUT=$(cat)

# --- extract fields ---
MODEL=$(printf '%s' "$INPUT" | jq -r '.model.display_name // "claude"')
IN_TOKENS=$(printf '%s' "$INPUT" | jq -r '.context_window.total_input_tokens // 0')
OUT_TOKENS=$(printf '%s' "$INPUT" | jq -r '.context_window.total_output_tokens // 0')
COST=$(printf '%s' "$INPUT" | jq -r '.cost.total_cost_usd // 0')
PCT=$(printf '%s' "$INPUT" | jq -r '.context_window.used_percentage // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.workspace.current_dir // empty')

TOTAL=$((IN_TOKENS + OUT_TOKENS))

# --- format tokens: 12.3k / 1.2M / raw ---
if [ "$TOTAL" -ge 1000000 ]; then
  TOK=$(awk -v t="$TOTAL" 'BEGIN{ printf "%.1fM", t/1000000 }')
elif [ "$TOTAL" -ge 1000 ]; then
  TOK=$(awk -v t="$TOTAL" 'BEGIN{ printf "%.1fk", t/1000 }')
else
  TOK="$TOTAL"
fi

# --- format cost: $0.0000 ---
COST_FMT=$(awk -v c="$COST" 'BEGIN{ printf "$%.4f", c }')

# --- ANSI helpers ---
RESET=$'\033[0m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'
RED=$'\033[31m'
ORANGE=$'\033[38;5;208m'
BLUE=$'\033[34m'

# --- context bar ---
CTX_SECTION=""
if [ -n "$PCT" ] && [ "$PCT" != "null" ]; then
  PCT_INT=$(awk -v p="$PCT" 'BEGIN{ printf "%d", p }')
  if [ "$PCT_INT" -lt 40 ]; then
    CTX_COLOR="$GREEN"
  elif [ "$PCT_INT" -lt 60 ]; then
    CTX_COLOR="$ORANGE"
  else
    CTX_COLOR="$RED"
  fi
  FILLED=$(awk -v p="$PCT_INT" 'BEGIN{ printf "%d", (p/10)+0.0001 }')
  [ "$FILLED" -gt 10 ] && FILLED=10
  [ "$FILLED" -lt 0 ] && FILLED=0
  EMPTY=$((10 - FILLED))
  BAR=""
  i=0
  while [ "$i" -lt "$FILLED" ]; do BAR="${BAR}#"; i=$((i+1)); done
  DOTS=""
  i=0
  while [ "$i" -lt "$EMPTY" ]; do DOTS="${DOTS}."; i=$((i+1)); done
  CTX_SECTION=" ${DIM}|${RESET} ${CTX_COLOR}ctx:[${BAR}${DIM}${DOTS}${RESET}${CTX_COLOR}] ${PCT_INT}%${RESET}"
fi

LINE1="${BOLD}${CYAN}${MODEL}${RESET} ${DIM}|${RESET} ${YELLOW}${TOK}${RESET} ${DIM}|${RESET} ${GREEN}${COST_FMT}${RESET}${CTX_SECTION}"

# --- line 2: cwd + branch ---
CWD_DISPLAY="$CWD"
if [ -n "$CWD" ]; then
  case "$CWD" in
    "$HOME"*) CWD_DISPLAY="~${CWD#$HOME}" ;;
  esac
fi

BRANCH=""
if [ -n "$CWD" ]; then
  BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || true)
fi

if [ -n "$BRANCH" ]; then
  LINE2="${BLUE}${CWD_DISPLAY}${RESET} ${DIM}(${RESET}${BOLD}${YELLOW}${BRANCH}${RESET}${DIM})${RESET}"
else
  LINE2="${BLUE}${CWD_DISPLAY}${RESET}"
fi

printf '%b\n%b\n' "$LINE1" "$LINE2"
