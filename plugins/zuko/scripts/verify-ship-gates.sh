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
      if ! printf '%s' "$subject" | grep -qE '^(feat|fix|chore|docs|refactor|test)(\([a-z0-9._-]+\))?: .+'; then
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
      if printf '%s\n' "$message" | grep -qiE 'claude-session:|https://claude\.ai/code/session_'; then
        reasons="$reasons
    $sha  carries a Claude-Session trailer"
      fi
      if printf '%s\n' "$message" | grep -qiE 'co-authored-by:.*(claude|noreply@anthropic\.com)'; then
        reasons="$reasons
    $sha  carries a Co-Authored-By trailer naming Claude"
      fi
      if printf '%s\n' "$message" | grep -qiE 'generated with claude code'; then
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
