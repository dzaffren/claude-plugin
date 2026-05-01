#!/bin/bash
# Analyse the current working-tree + staged diff and suggest atomic commit
# groupings. Output is a plain-text plan the caller (or /ship) surfaces to the
# user for approval before committing.
#
# Heuristics (kept intentionally simple — the LLM refines the output):
#   · Group files by top-level directory (docs/, tests/, src/*, etc.).
#   · Map each group to a conventional-commit type:
#       tests/ or *.test.*         → test
#       docs/ or *.md (top level)  → docs
#       scripts/ or package.json   → chore
#       CHANGELOG.md               → chore
#       everything else            → feat (reviewer overrides if it's a fix)
#   · Scope = second path segment when available, else the top-level dir name.
#
# Output format:
#   <N> proposed commit(s):
#     1. <type>(<scope>): <short subject>
#        files:
#          - path/one
#          - path/two
#   ...
# Followed by: "Accept plan? (y/n/edit)"

set -eu

FILES=$(git status --porcelain | awk '{print $2}' | sort -u)
if [ -z "$FILES" ]; then
  echo "0 proposed commit(s): working tree is clean."
  exit 0
fi

classify() {
  local path=$1
  case "$path" in
    CHANGELOG.md) echo "chore|changelog" ;;
    docs/*|README.md|*/README.md) echo "docs|${path%%/*}" ;;
    tests/*|test/*|*.test.*|*.spec.*|*_test.go|__tests__/*) echo "test|${path%%/*}" ;;
    scripts/*|.github/*|.gitlab-ci.yml|Makefile|*.json|*.toml|*.yml|*.yaml)
      echo "chore|${path%%/*}" ;;
    *)
      local scope
      scope=$(echo "$path" | awk -F/ 'NF>=2{print $2; exit} {print $1}')
      echo "feat|$scope"
      ;;
  esac
}

declare -a KEYS=()
declare -a GROUPS_TYPE=()
declare -a GROUPS_SCOPE=()
declare -a GROUPS_FILES=()

for f in $FILES; do
  cls=$(classify "$f")
  type=${cls%%|*}
  scope=${cls#*|}
  key="${type}|${scope}"
  found=-1
  for i in "${!KEYS[@]}"; do
    if [ "${KEYS[$i]}" = "$key" ]; then
      found=$i
      break
    fi
  done
  if [ "$found" -ge 0 ]; then
    GROUPS_FILES[$found]="${GROUPS_FILES[$found]}
$f"
  else
    KEYS+=("$key")
    GROUPS_TYPE+=("$type")
    GROUPS_SCOPE+=("$scope")
    GROUPS_FILES+=("$f")
  fi
done

N=${#KEYS[@]}
echo "${N} proposed commit(s):"
i=1
for idx in "${!KEYS[@]}"; do
  type=${GROUPS_TYPE[$idx]}
  scope=${GROUPS_SCOPE[$idx]}
  files=${GROUPS_FILES[$idx]}
  first=$(echo "$files" | head -n1)
  subject="${type}(${scope}): update $(basename "$first")"
  if [ "$(echo "$files" | wc -l)" -gt 1 ]; then
    subject="${type}(${scope}): update ${scope} files"
  fi
  echo "  ${i}. ${subject}"
  echo "     files:"
  echo "$files" | sed 's/^/       - /'
  i=$((i + 1))
done

echo ""
echo "Accept plan? (y / n / edit)"
