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
live=()   # Draft or Refined specs and every shape: the glossary check reads these
docs=()   # every doc in scope, at any Status: the fence check reads these (D76)

# Only the zuko docs this work touched (D35, D36).
if ! scope=$(python3 "$(dirname "${BASH_SOURCE[0]}")/lib/stop_scope.py" "$dir" 2>&1); then
  problems="$problems
- the docs to judge could not be listed: $scope"
  scope=""
fi

while IFS= read -r md; do
  [ -n "$md" ] || continue
  docs+=("$md")
  base=$(basename "$md" .md)
  if [ "$base" = "shape" ]; then
    live+=("$md")
    continue
  fi

  status=$(grep -oE '\*\*Status:\*\*[[:space:]]*[A-Za-z]+' "$md" 2>/dev/null | head -1 | awk '{print $2}')
  case "${status:-missing}" in
    Draft|Refined) live+=("$md") ;;
    Built|Shipped) ;;
    *) problems="$problems
- $md has Status '${status:-missing}' — must be Draft, Refined, Built, or Shipped." ;;
  esac

  if grep -qE -- '-v[0-9]+$' <<<"$base"; then
    problems="$problems
- $md is a versioned spec outside archive/. Old iterations live in docs/specs/archive/; the live spec has no -vN suffix."
  fi

  grep -q '^## Open items' "$md" || problems="$problems
- $md has no '## Open items' section. The ledger is never deleted, even when empty."
done <<<"$scope"

if [ "${#live[@]}" -gt 0 ]; then
  if undefined=$(python3 "$(dirname "${BASH_SOURCE[0]}")/lib/glossary.py" missing "${live[@]}" 2>&1); then
    while IFS=$'\t' read -r md term; do
      [ -n "$md" ] && problems="$problems
- $md uses $term with no ## Glossary entry for it."
    done <<<"$undefined"
  else
    problems="$problems
- the glossary check could not run: $undefined"
  fi
fi

if [ "${#docs[@]}" -gt 0 ]; then
  if swallowed=$(python3 "$(dirname "${BASH_SOURCE[0]}")/lib/fence.py" check "${docs[@]}" 2>&1); then
    while IFS=$'\t' read -r md problem; do
      [ -n "$md" ] || continue
      case "$problem" in
        line*) problems="$problems
- $md $problem" ;;
        *) problems="$problems
- $md: $problem" ;;
      esac
    done <<<"$swallowed"
  else
    problems="$problems
- the fence check could not run: $swallowed"
  fi
fi

if [ -n "$problems" ]; then
  { echo "Spec gate check failed:"; echo "$problems"; } >&2
  exit 2
fi
exit 0
