#!/usr/bin/env bash
# SessionStart hook: inject the repo's captured lessons into context.
set -euo pipefail

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
index="$dir/docs/learnings/INDEX.md"

if [ -f "$index" ]; then
  echo "Repo lessons from docs/learnings/ (apply these; open a lesson file only if the one-line rule needs detail):"
  cat "$index"
fi
