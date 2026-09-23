#!/usr/bin/env bash
# SessionStart hook: inject the repo's OVERVIEW.md into context, capped at 150 lines.
# Never blocks a session: every state exits 0 and says what happened.
set -uo pipefail

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
file="$dir/OVERVIEW.md"
cap=150
byte_cap=16384

# A symlink could point anywhere on disk; never follow one into context.
if [ -L "$file" ]; then
  echo "OVERVIEW.md is a symlink — not loaded."
  exit 0
fi

if [ ! -f "$file" ]; then
  echo "No OVERVIEW.md — the next zuko stage will onboard this repo."
  exit 0
fi

status=$(grep -oE '\*\*Status:\*\*[[:space:]]*[A-Za-z]+' "$file" 2>/dev/null | head -1 | awk '{print $2}')

case "$status" in
  Active) echo "Project overview (OVERVIEW.md):" ;;
  Draft) echo "Project overview (OVERVIEW.md) — Draft — not yet confirmed:" ;;
  *)
    echo "OVERVIEW.md has no Status line — loaded as Draft."
    echo "Project overview (OVERVIEW.md) — Draft — not yet confirmed:"
    ;;
esac

head -n "$cap" "$file" 2>/dev/null | head -c "$byte_cap" | awk '1'
# awk counts a last line with no newline; wc -l does not.
lines=$(awk 'END { print NR }' "$file" 2>/dev/null)
bytes=$(head -n "$cap" "$file" 2>/dev/null | wc -c | tr -d ' ')
if [ "${lines:-0}" -gt "$cap" ]; then
  echo "Warning: OVERVIEW.md is $lines lines; loaded the first $cap. Trim it to $cap."
fi
if [ "${bytes:-0}" -gt "$byte_cap" ]; then
  echo "Warning: OVERVIEW.md is over $byte_cap bytes; loaded the first $byte_cap. Trim it."
fi
exit 0
