#!/usr/bin/env bash
# Stop hook: mechanical checks on the spec files themselves.
set -uo pipefail

input=$(cat 2>/dev/null || true)
active=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("stop_hook_active", False))' 2>/dev/null) || active=False
[ "$active" = "True" ] && exit 0

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
specs="$dir/docs/specs"
[ -d "$specs" ] || exit 0
problems=""

while IFS= read -r md; do
  base=$(basename "$md" .md)
  [ "$base" = "shape" ] && continue

  status=$(grep -oE '\*\*Status:\*\*[[:space:]]*[A-Za-z]+' "$md" 2>/dev/null | head -1 | awk '{print $2}')
  case "${status:-missing}" in
    Draft|Refined|Built|Shipped) ;;
    *) problems="$problems
- $md has Status '${status:-missing}' — must be Draft, Refined, Built, or Shipped." ;;
  esac

  if printf '%s' "$base" | grep -qE -- '-v[0-9]+$'; then
    problems="$problems
- $md is a versioned spec outside archive/. Old iterations live in docs/specs/archive/; the live spec has no -vN suffix."
  fi

  grep -q '^## Open items' "$md" || problems="$problems
- $md has no '## Open items' section. The ledger is never deleted, even when empty."
done < <(find "$specs" -maxdepth 2 -name '*.md' ! -path '*/archive/*' 2>/dev/null)

if [ -n "$problems" ]; then
  { echo "Spec gate check failed:"; echo "$problems"; } >&2
  exit 2
fi
exit 0
