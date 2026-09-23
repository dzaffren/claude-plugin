#!/usr/bin/env bash
# SessionStart hook: inject the repo's OVERVIEW.md into context, capped at 150 lines.
# Never blocks a session: every state exits 0 and says what happened.
set -uo pipefail

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
file="$dir/OVERVIEW.md"
cap=150

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

head -n "$cap" "$file" 2>/dev/null
lines=$(wc -l <"$file" 2>/dev/null | tr -d ' ')
if [ "${lines:-0}" -gt "$cap" ]; then
  echo "Warning: OVERVIEW.md is $lines lines; loaded the first $cap. Trim it to $cap."
fi
exit 0
