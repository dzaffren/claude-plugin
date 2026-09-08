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

# Placeholders left in the spec.
ph=$(grep -nE '\{[a-z][^}]*\}|\[TBD\]|TODO' "$spec" 2>/dev/null | grep -vE '/s/\{token\}|\{N\}|GET /|POST /' | head -5 || true)
[ -n "$ph" ] && problems="$problems
- Placeholders left in the spec:
$ph"

# Branch state.
branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo "")
case "$branch" in
  main|master|"") problems="$problems
- On branch '${branch:-detached}'. Ship from a feature branch." ;;
esac

# Uncommitted work.
if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
  problems="$problems
- Working tree is dirty. Commit or stash before shipping."
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
