#!/usr/bin/env bash
# Gate: mechanical pre-ship checks. Reports; /ship checks the rest by hand.
# Usage: verify-ship-gates.sh [<spec.md>]
set -uo pipefail

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
spec="${1:-}"
problems=""
notes=""

if [ -z "$spec" ]; then
  spec=$(find "$dir/docs/specs" -maxdepth 1 -name '*.md' ! -path '*/archive/*' 2>/dev/null \
    | xargs grep -lE '\*\*Status:\*\*[[:space:]]*Built' 2>/dev/null | head -1)
fi

if [ -z "$spec" ] || [ ! -f "$spec" ]; then
  echo "No spec at Status 'Built' found. Name one explicitly, or check the spec's status."
  exit 1
fi

echo "Spec: $spec"

# Open ledger rows.
rows=$(grep -nE '^\|[[:space:]]*O[0-9]+[[:space:]]*\|.*\|[[:space:]]*Open[[:space:]]*\|' "$spec" 2>/dev/null || true)
[ -n "$rows" ] && problems="$problems
- Ledger still has open items:
$rows"

# Ledger section must exist at all.
grep -q '^## Open items' "$spec" || problems="$problems
- Spec has no '## Open items' section. The ledger is never deleted."

# Overview: the slice (the spec's basename) needs a row in OVERVIEW.md's
# slices table. Matched by the first cell exactly, inside '## Slices' only, and
# a file that could not be read is never a pass.
slice=$(basename "$spec" .md)
overview="$dir/OVERVIEW.md"
if [ -L "$overview" ]; then
  problems="$problems
- OVERVIEW.md  is a symlink — the session loader will not load it"
elif [ ! -f "$overview" ]; then
  problems="$problems
- OVERVIEW.md  not onboarded — run any writing stage first"
else
  ov_status=$(grep -oE '\*\*Status:\*\*[[:space:]]*[A-Za-z]+' "$overview" 2>/dev/null | head -1 | awk '{print $2}')
  # Only Active passes. Anything else is named, so a typo never reads as approval.
  case "$ov_status" in
    Draft) problems="$problems
- OVERVIEW.md  overview still Draft — approve it before shipping" ;;
    "") problems="$problems
- OVERVIEW.md  has no Status line — approve the onboarding draft first" ;;
    Active)
      # Fenced blocks are examples, never the table.
      if awk -v s="$slice" '
        /^[[:space:]]*(```|~~~)/ { fenced = !fenced; next }
        fenced { next }
        /^## / { on = ($0 ~ /^## Slices[[:space:]]*$/); next }
        on && /^[[:space:]]*\|/ {
          split($0, cell, "|"); c = cell[2]
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", c)
          if (c == s) found = 1
        }
        END { exit !found }' "$overview" 2>/dev/null; then
        echo "Overview: row for \"$slice\" found"
      else
        problems="$problems
- OVERVIEW.md  slices table has no row for \"$slice\""
      fi
      ;;
    *) problems="$problems
- OVERVIEW.md  status is '$ov_status', not Active — approve the onboarding draft first" ;;
  esac
fi

# README: the zuko block must match what OVERVIEW.md renders to. Any non-zero
# exit is a problem -- exit 2, a block the renderer cannot place, is never a
# pass. The first line is the reason; the diff, if any, is indented under it.
readme_out=$(CLAUDE_PROJECT_DIR="$dir" bash "$(dirname "${BASH_SOURCE[0]}")/render-readme-block.sh" --check 2>&1)
if [ $? -eq 0 ]; then
  echo "README: zuko block matches OVERVIEW.md"
else
  problems="$problems
- $(printf '%s\n' "$readme_out" | head -1)"
  readme_diff=$(printf '%s\n' "$readme_out" | tail -n +2 | sed 's/^/    /')
  [ -n "$readme_diff" ] && problems="$problems
$readme_diff"
fi

# Rollout / rollback must be stated.
grep -qiE '\*\*Rollout\*\*|^\| \*\*Rollout\*\*' "$spec" || problems="$problems
- No Rollout line in the non-functionals. State the flag and the rollback path."

# Proof signal must be stated.
grep -qiE '\*\*Proof it works\*\*' "$spec" || problems="$problems
- No 'Proof it works' line. Name the log line or metric that proves it in prod."

# E2E must be named.
grep -qiE '\*\*E2E:\*\*|e2e' "$spec" || problems="$problems
- No end-to-end test named in the test plan."

# Placeholders left in the spec. The exclusion list names the tokens this
# workflow writes down on purpose -- the convention's own {type}/{slice}, and
# mermaid's {{node}} syntax -- because a documented format and an unfilled
# blank are the same text, and only the list can tell them apart.
ph=$(grep -nE '\{[a-z][^}]*\}|\[TBD\]|TODO' "$spec" 2>/dev/null \
  | grep -vE '/s/\{token\}|\{N\}|GET /|POST /|\{\{|\{type\}|\{scope\}|\{subject\}|\{slice\}|\{question\}' \
  | head -5 || true)
[ -n "$ph" ] && problems="$problems
- Placeholders left in the spec:
$ph"

# Branch state.
branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo "")
case "$branch" in
  main|master|"") problems="$problems
- On branch '${branch:-detached}'. Ship from a feature branch." ;;
  *)
    printf '%s' "$branch" | grep -qE '^(feat|fix|chore|docs|refactor|test)/[^/]+$' || problems="$problems
- Branch '$branch' is not {type}/{slice}. Types: feat fix chore docs refactor test." ;;
esac

# Uncommitted work.
if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
  problems="$problems
- Working tree is dirty. Commit or stash before shipping."
fi

# Claude attribution, as references/git-naming.md bans it. One list: the
# naming check reads it for commit messages, the changelog check for the
# lines a branch adds to CHANGELOG.md.
ban_session='claude-session:|https://claude\.ai/code/session_'
ban_coauthor='co-authored-by:.*(claude|noreply@anthropic\.com)'
ban_generated='generated with claude code'

# Naming, over every commit ahead of the base. An empty range and a base that
# will not resolve are the same failure: a gate that scanned nothing is not a
# pass, so neither is allowed to look like one.
base_ref=""
for candidate in "$(git -C "$dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)" main master; do
  [ -n "$candidate" ] || continue
  if git -C "$dir" rev-parse --verify --quiet "$candidate" >/dev/null 2>&1; then
    base_ref="$candidate"
    break
  fi
done

base=""
[ -n "$base_ref" ] && base=$(git -C "$dir" merge-base HEAD "$base_ref" 2>/dev/null || true)

if [ -z "$base" ]; then
  problems="$problems
- No base branch to compare against (tried origin/HEAD, main, master). A gate that scanned nothing is not a pass."
else
  shas=$(git -C "$dir" log --reverse --format=%h "$base"..HEAD 2>/dev/null || true)
  count=$(printf '%s\n' "$shas" | grep -c . || true)
  if [ "$count" -eq 0 ]; then
    problems="$problems
- No commits on '${branch:-detached}' ahead of ${base_ref#origin/}. A gate that scanned nothing is not a pass."
  else
    echo "Naming: checked $count commits on ${branch:-detached} ahead of ${base_ref#origin/}."
    broken=0
    report=""
    while read -r sha; do
      [ -z "$sha" ] && continue
      subject=$(git -C "$dir" log -1 --format=%s "$sha")
      message=$(git -C "$dir" log -1 --format=%B "$sha")
      reasons=""
      if ! printf '%s' "$subject" | grep -qE '^(feat|fix|chore|docs|refactor|test)(\([a-z0-9._-]+\))?!?: .+'; then
        reasons="$reasons
    $sha  subject is not {type}({scope}): {subject}
             \"$subject\""
      else
        case "$subject" in
          *.) reasons="$reasons
    $sha  subject ends with a period" ;;
        esac
        [ "${#subject}" -gt 72 ] && reasons="$reasons
    $sha  subject is longer than 72 characters"
      fi
      if printf '%s\n' "$message" | grep -qiE "$ban_session"; then
        reasons="$reasons
    $sha  carries a Claude-Session trailer"
      fi
      if printf '%s\n' "$message" | grep -qiE "$ban_coauthor"; then
        reasons="$reasons
    $sha  carries a Co-Authored-By trailer naming Claude"
      fi
      if printf '%s\n' "$message" | grep -qiE "$ban_generated"; then
        reasons="$reasons
    $sha  carries a \"Generated with Claude Code\" line"
      fi
      if [ -n "$reasons" ]; then
        broken=$((broken + 1))
        report="$report$reasons"
      fi
    done <<SHAS
$shas
SHAS
    if [ "$broken" -gt 0 ]; then
      problems="$problems
- $broken of $count commits break the naming convention:$report"
    fi
  fi

  # Decisions: against the same base, so "what this branch changed" has one
  # definition. Every non-zero exit is a problem, one per line it printed.
  decisions_out=$(python3 "$(dirname "${BASH_SOURCE[0]}")/lib/decisions.py" check "$dir" --base "$base" --label "${base_ref#origin/}" 2>&1)
  if [ $? -eq 0 ]; then
    echo "$decisions_out"
  else
    problems="$problems
$(printf '%s\n' "$decisions_out" | sed 's/^/- /')"
  fi

  # Changelog: against the same base. A feat or fix branch adds a line under
  # [Unreleased]. Every non-zero exit is a problem -- exit 2, a base it cannot
  # read, is never a pass. A problem line gets "- "; its indented detail
  # lines keep their indent, so the commit listing stays under its problem.
  changelog_out=$(python3 "$(dirname "${BASH_SOURCE[0]}")/lib/changelog.py" check "$dir" --base "$base" --label "${base_ref#origin/}" 2>&1)
  if [ $? -eq 0 ]; then
    echo "$changelog_out"
  else
    problems="$problems
$(printf '%s\n' "$changelog_out" | sed 's/^[^ ]/- &/')"
  fi

  # The lines this branch added to CHANGELOG.md, and only those, carry no
  # attribution: a line already on the base is not this branch's to fix.
  # The flags pin a plain unified diff whatever the repo's colour, external
  # diff or -diff attribute say -- any of those would leave no "+" lines.
  attributed=$(git -C "$dir" diff --no-color --no-ext-diff --text "$base"..HEAD -- CHANGELOG.md 2>/dev/null \
    | grep '^+' | grep -v '^+++' | cut -c2- \
    | grep -iE "$ban_session|$ban_coauthor|$ban_generated" || true)
  while IFS= read -r line; do
    [ -n "$line" ] && problems="$problems
- CHANGELOG.md  new line carries Claude attribution: \"$line\""
  done <<ATTRIBUTED
$attributed
ATTRIBUTED
fi

# Spike branches left alive.
spikes=$(git -C "$dir" branch --list 'spike/*' 2>/dev/null | tr -d ' *' || true)
[ -n "$spikes" ] && notes="$notes
- Spike branches still alive (delete them): $spikes"

if [ -n "$problems" ]; then
  echo "Ship gates FAILED:$problems"
  [ -n "$notes" ] && echo "Also:$notes"
  exit 1
fi

echo "Mechanical ship gates passed.$notes"
echo ""
echo "Still to check by hand: full suite green just now, e2e passing, migration reversed in tests, flag actually removes the behaviour, review findings fixed, no files touched outside the plan."
exit 0
