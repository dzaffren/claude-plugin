#!/usr/bin/env bash
# Stop hook: mechanical checks that the workflow's doc gates hold before the
# turn ends. Blocks (exit 2) with a fix-it message when they don't.
set -uo pipefail

input=$(cat)

# Don't loop: if this hook already fired for this stop, let the turn end.
active=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("stop_hook_active", False))' 2>/dev/null) || exit 0
[ "$active" = "True" ] && exit 0

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
problems=""

for docs in "$dir/docs/specs" "$dir/docs/discovery" "$dir/docs/walkthroughs"; do
  [ -d "$docs" ] || continue
  while IFS= read -r md; do
    html="${md%.md}.html"
    if [ ! -f "$html" ]; then
      problems="$problems
- $md has no HTML view. Run: python3 \${CLAUDE_PLUGIN_ROOT}/skills/spec-html/scripts/md2html.py $md"
    elif [ "$md" -nt "$html" ]; then
      problems="$problems
- $md is newer than its HTML view. Regenerate it."
    fi
  done < <(find "$docs" -name '*.md' ! -name 'INDEX.md' 2>/dev/null)
done

specs="$dir/docs/specs"
if [ -d "$specs" ]; then
  while IFS= read -r md; do
    status=$(grep -oE '\*\*Status:\*\*[[:space:]]*[A-Za-z-]+' "$md" | head -1 | awk '{print $2}')
    case "${status:-missing}" in
      Draft|Refined|Built|Shipped) ;;
      *) problems="$problems
- $md has Status '${status:-missing}' — must be Draft, Refined, Built, or Shipped." ;;
    esac
    if basename "$md" .md | grep -qE -- '-v[0-9]+$'; then
      problems="$problems
- $md is a versioned spec outside archive/. Old iterations belong in docs/specs/archive/; the live spec has no -vN suffix."
    fi
  done < <(find "$specs" -maxdepth 2 -name '*.md' ! -path '*/archive/*' 2>/dev/null)
fi

if [ -n "$problems" ]; then
  {
    echo "Workflow gate check failed:"
    echo "$problems"
  } >&2
  exit 2
fi
exit 0
