#!/usr/bin/env bash
# Gate: UI written into the repo must use the design system, not invent values.
# Usage: check-design-drift.sh <file-or-dir> [<file-or-dir> ...]
# Exit 1 with a report on any violation. Advisory when no token file is found.
set -uo pipefail

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=("$dir/docs/design")

# Find the token definitions the project actually uses.
token_files=$(find "$dir" \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' -not -path '*/build/*' \
  \( -name 'tokens*.css' -o -name 'theme.css' -o -name 'globals.css' -o -name 'tailwind.config.*' -o -name 'components.json' \) \
  2>/dev/null | head -20)

known_tokens=""
if [ -n "$token_files" ]; then
  known_tokens=$(printf '%s\n' "$token_files" | while read -r f; do
    [ -f "$f" ] && grep -ohE -- '--[a-zA-Z0-9_-]+' "$f" 2>/dev/null
  done | sort -u)
fi

scan=$(printf '%s\n' "${targets[@]}" | while read -r t; do
  [ -e "$t" ] || continue
  find "$t" -type f \( -name '*.html' -o -name '*.css' -o -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.svelte' \) 2>/dev/null
done)
[ -z "$scan" ] && exit 0

problems=""

# 1. Raw hex colours.
hits=$(printf '%s\n' "$scan" | while read -r f; do
  grep -nE '#[0-9a-fA-F]{3,8}\b' "$f" 2>/dev/null | grep -vE '(--[a-zA-Z0-9_-]+[[:space:]]*:|@dsCard|currentColor)' | sed "s|^|$f:|" | head -5
done)
[ -n "$hits" ] && problems="$problems

Raw hex colours — use a design system token instead:
$hits"

# 2. Tailwind arbitrary values.
hits=$(printf '%s\n' "$scan" | while read -r f; do
  grep -nE '\b(w|h|p|px|py|pt|pb|pl|pr|m|mx|my|mt|mb|ml|mr|gap|text|leading|rounded|top|left|right|bottom)-\[[^]]+\]' "$f" 2>/dev/null | sed "s|^|$f:|" | head -5
done)
[ -n "$hits" ] && problems="$problems

Arbitrary values — use a step on the scale instead:
$hits"

# 3. Animating layout properties.
hits=$(printf '%s\n' "$scan" | while read -r f; do
  grep -nE 'transition[^;]*:[^;]*(width|height|top|left|right|bottom|margin|padding)' "$f" 2>/dev/null | sed "s|^|$f:|" | head -5
done)
[ -n "$hits" ] && problems="$problems

Animating a layout property — animate transform and opacity only:
$hits"

# 4. Emoji in UI. Matched on UTF-8 bytes: PCRE builds vary on codepoints
# above U+FFFF, byte matching does not.
emoji_bytes=$'\xF0\x9F[\x80-\xBF][\x80-\xBF]|\xE2[\x98-\x9E][\x80-\xBF]|\xEF\xB8\x8F|\xE2\xAD\x90|\xE2\x9C\x85|\xE2\x9D\x8C'
hits=$(printf '%s\n' "$scan" | while read -r f; do
  LC_ALL=C grep -nE "$emoji_bytes" "$f" 2>/dev/null | sed "s|^|$f:|" | head -5
done)
[ -n "$hits" ] && problems="$problems

Emoji in the interface — use an icon set:
$hits"

# 5. Placeholder content.
hits=$(printf '%s\n' "$scan" | while read -r f; do
  grep -niE 'lorem ipsum|\[placeholder\]|your (product|company) (name|here)|TODO: copy' "$f" 2>/dev/null | sed "s|^|$f:|" | head -5
done)
[ -n "$hits" ] && problems="$problems

Placeholder content — use the spec's real examples:
$hits"

# 6. Generated-UI copy tells.
hits=$(printf '%s\n' "$scan" | while read -r f; do
  grep -niE 'elevate your|supercharge your|unlock the power|take your .* to the next level|seamlessly (integrate|connect)|best-in-class|game-chang' "$f" 2>/dev/null | sed "s|^|$f:|" | head -5
done)
[ -n "$hits" ] && problems="$problems

Generated-UI copy — write what this product actually does:
$hits"

# 7. Unknown tokens, only checkable when tokens were found.
if [ -n "$known_tokens" ]; then
  hits=$(printf '%s\n' "$scan" | while read -r f; do
    grep -ohE -- 'var\(--[a-zA-Z0-9_-]+' "$f" 2>/dev/null | sed 's/var(//' | while read -r tok; do
      printf '%s\n' "$known_tokens" | grep -qxF -- "$tok" || echo "$f: $tok"
    done
  done | sort -u | head -8)
  [ -n "$hits" ] && problems="$problems

Tokens not defined in the design system — propose them to the system, do not invent them here:
$hits"
fi

if [ -n "$problems" ]; then
  echo "Design drift check FAILED.$problems"
  echo ""
  echo "Fix these and re-render before showing the user. Anything the design system genuinely lacks is a proposal to the system, not a one-off here."
  exit 1
fi

if [ -z "$known_tokens" ]; then
  echo "Design drift check passed (advisory: no design system token file found, so token names were not verified)."
else
  echo "Design drift check passed."
fi
exit 0
