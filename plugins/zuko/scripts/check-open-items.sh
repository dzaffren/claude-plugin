#!/usr/bin/env bash
# Gate: no shape may be Shaped, and no spec Refined, Built or Shipped, while a
# ledger row is still Open. A shape's 'Handed to SLICE' row is not Open.
# Used two ways:
#   - Stop hook, no args: checks every live spec and shape, blocks the turn on a breach.
#   - With a spec path: prints that spec's open rows, exit 1 if any (for /build).
set -uo pipefail

dir="${CLAUDE_PROJECT_DIR:-$PWD}"

# Open rows look like:  | O2 | ... | Open | ... |
open_rows() {
  grep -nE '^\|[[:space:]]*O[0-9]+[[:space:]]*\|.*\|[[:space:]]*Open[[:space:]]*\|' "$1" 2>/dev/null || true
}

spec_status() {
  grep -oE '\*\*Status:\*\*[[:space:]]*[A-Za-z]+' "$1" 2>/dev/null | head -1 | awk '{print $2}'
}

# --- direct mode: one spec, called by /build ------------------------------
# An argument means direct mode, always. A bad path is an error, never a
# silent fall-through to hook mode -- that would pass a spec it never read.
if [ $# -ge 1 ]; then
  if [ ! -f "$1" ]; then
    echo "check-open-items.sh: no such spec: $1" >&2
    exit 1
  fi
  rows=$(open_rows "$1")
  if [ -n "$rows" ]; then
    echo "Open items in $1 — /build cannot start until each is Resolved or Accepted risk:"
    echo "$rows"
    exit 1
  fi
  echo "No open items in $1."
  exit 0
fi

# --- hook mode: stdin is the hook payload ---------------------------------
input=$(cat 2>/dev/null || true)

# Don't loop on ourselves.
active=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("stop_hook_active", False))' 2>/dev/null) || active=False
[ "$active" = "True" ] && exit 0

specs="$dir/docs/specs"
[ -d "$specs" ] || exit 0

# Only the zuko docs this work touched (D35, D36).
if ! scope=$(python3 "$(dirname "${BASH_SOURCE[0]}")/lib/stop_scope.py" "$dir" 2>&1); then
  echo "Open-items gate failed: the docs to judge could not be listed: $scope" >&2
  exit 2
fi

problems=""
while IFS= read -r md; do
  [ -n "$md" ] || continue
  status=$(spec_status "$md")
  case "$(basename "$md"):${status:-}" in
    shape.md:Shaped) ;;
    shape.md:*) continue ;;
    *:Refined|*:Built|*:Shipped) ;;
    *) continue ;;
  esac
  rows=$(open_rows "$md")
  if [ -n "$rows" ]; then
    problems="$problems
- $md is '$status' but still has open ledger items:
$rows"
  fi
done <<<"$scope"

if [ -n "$problems" ]; then
  {
    echo "Open-items gate failed. A shape cannot be Shaped, and a spec cannot be Refined,"
    echo "Built or Shipped, with unresolved items."
    echo "$problems"
    echo ""
    echo "Resolve each row (write the answer into the row), mark it 'Accepted risk' with a"
    echo "reason and a date, or in a shape hand it to a later slice. Never delete a row."
  } >&2
  exit 2
fi
exit 0
