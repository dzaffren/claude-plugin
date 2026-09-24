#!/usr/bin/env bash
# SessionStart hook: list the repo's active decisions from DECISIONS.md, one
# title per line. Never blocks a session: every state exits 0.
set -uo pipefail

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
file="$dir/DECISIONS.md"

# A symlink could point anywhere on disk; never follow one into context.
if [ -L "$file" ]; then
  echo "DECISIONS.md is a symlink — not loaded."
  exit 0
fi

[ -f "$file" ] || exit 0

titles=$(python3 "$(dirname "${BASH_SOURCE[0]}")/lib/decisions.py" titles "$dir" 2>/dev/null)
# A parser failure prints nothing too; never let it read as an empty file.
if [ $? -ne 0 ]; then
  echo "DECISIONS.md could not be read — run decisions.py titles to see why. Active decisions were not loaded."
  exit 0
fi
if [ -z "$titles" ]; then
  echo "DECISIONS.md has no entries yet."
  exit 0
fi

echo "Active decisions (DECISIONS.md) — check before proposing; supersede, don't contradict:"
printf '%s\n' "$titles" | sed 's/^/  /'
exit 0
