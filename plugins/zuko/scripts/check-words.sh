#!/usr/bin/env bash
# PostToolUse[Write|Edit] hook: tell Claude which added lines of a shape or spec
# use a hard word, so it fixes them before the user reads the doc (D178).
# Exit 2 puts stderr in front of Claude in the same turn.
set -uo pipefail

file=$(python3 -I -c 'import json,sys; [s.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n") for s in (sys.stdin, sys.stdout)]; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null) || exit 0
[ -f "$file" ] || exit 0
dir="${CLAUDE_PROJECT_DIR:-$PWD}"

if ! found=$(python3 "$(dirname "${BASH_SOURCE[0]}")/lib/words.py" check "$dir" "$file" 2>&1); then
  echo "Word check could not run: $found" >&2
  exit 2
fi
[ -n "$found" ] || exit 0

{
  echo "Word check: $(python3 -I -c 'import os,sys; [s.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n") for s in (sys.stdin, sys.stdout)]; print(os.path.relpath(sys.argv[1], sys.argv[2]).replace(os.sep, "/"))' "$file" "$dir")"
  while IFS=$'\t' read -r _ line message; do
    echo "- line $line: $message"
  done <<<"$found"
  echo "Fix these lines now. The check reads only the lines that this work added."
} >&2
exit 2
