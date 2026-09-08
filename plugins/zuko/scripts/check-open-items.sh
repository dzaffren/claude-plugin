#!/usr/bin/env bash
# Gate: no spec may be Built or Shipped while a ledger row is still Open.
# Used two ways:
#   - Stop hook, no args: checks every live spec, blocks the turn on a breach.
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
if [ $# -ge 1 ] && [ -f "$1" ]; then
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

problems=""
while IFS= read -r md; do
  status=$(spec_status "$md")
  case "${status:-}" in
    Built|Shipped)
      rows=$(open_rows "$md")
      if [ -n "$rows" ]; then
        problems="$problems
- $md is '$status' but still has open ledger items:
$rows"
      fi
      ;;
  esac
done < <(find "$specs" -maxdepth 2 -name '*.md' ! -path '*/archive/*' 2>/dev/null)

if [ -n "$problems" ]; then
  {
    echo "Open-items gate failed. A spec cannot be Built or Shipped with unresolved items."
    echo "$problems"
    echo ""
    echo "Resolve each row (write the answer into the row), or mark it 'Accepted risk' with a reason and a date. Never delete a row."
  } >&2
  exit 2
fi
exit 0
