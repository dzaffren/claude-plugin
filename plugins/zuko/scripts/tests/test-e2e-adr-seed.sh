# One walk through the adr-seeding slice: a repo with seven ADRs, adr-scan,
# a DECISIONS.md written from its output, the check onboarding runs, the
# session loader, and the check refusing a broken supersede pair.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

# Inside run.sh's own temp dir, which its EXIT trap removes.
work=$(mktemp -d -p "$work")
repo="$work/invoice-cli"
mkdir -p "$repo/docs/adr"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester
cp "$scripts"/tests/fixtures/adr/*.md "$repo/docs/adr/"
git -C "$repo" add -A
GIT_AUTHOR_DATE="2025-03-20T10:00:00" GIT_COMMITTER_DATE="2025-03-20T10:00:00" \
  git -C "$repo" commit -q --no-verify -m "docs: add ADRs"

# 1. Onboarding scans the ADRs.
scan_out=$(python3 "$scripts/lib/decisions.py" adr-scan "$repo" 2>&1)
expect_exit 0 "$?" "e2e: adr-scan runs on the repo"

# 2. Onboarding writes DECISIONS.md from the scan, the way onboard.md says:
# every seeded ADR in D order, honest-gap Rejected lines, the pair linked.
printf '%s' "$scan_out" | python3 -c '
import json, sys
print("# Decisions\n")
print("Append-only. A changed decision is a new entry that supersedes the old one; only an")
print("old entry'"'"'s Status line ever changes.")
for adr in json.load(sys.stdin):
    if not adr["seed"]:
        continue
    print("\n## D%d · %s · %s\n" % (adr["d"], adr["date"], adr["title"]))
    print("Why: seeded from %s." % adr["file"])
    print("Rejected: not recorded in %s" % adr["file"])
    if adr["supersedes_d"]:
        print("Supersedes: D%d" % adr["supersedes_d"])
    print("Source: %s" % adr["file"])
    status = "superseded by D%d" % adr["superseded_by_d"] if adr["superseded_by_d"] else "active"
    print("Status: %s" % status)
' >"$repo/DECISIONS.md"
expect_match '^## D2 · 2025-03-09 · Use Postgres$' "$(cat "$repo/DECISIONS.md")" "e2e: D2 is Use Postgres, dated from the ADR"
expect_match '^## D3 · 2025-03-20 · Ship as a pip package$' "$(cat "$repo/DECISIONS.md")" "e2e: D3 dated from its first commit"
expect_match '^Rejected: not recorded in docs/adr/0003-ship-as-pip-package\.md$' "$(cat "$repo/DECISIONS.md")" \
  "e2e: D3 carries the honest-gap line"
expect_no_match 'graphql|xml-export' "$(cat "$repo/DECISIONS.md")" "e2e: Proposed and Deprecated ADRs are not seeded"

# 3. The check onboarding runs on the new, uncommitted log.
check_out=$(python3 "$scripts/lib/decisions.py" check "$repo" 2>&1)
expect_exit 0 "$?" "e2e: the seeded log passes check"
expect_match '^Decisions: 5 entries checked$' "$check_out" "e2e: five entries seeded"

# 4. Committed, the ship gate's form of the check passes too.
git -C "$repo" add DECISIONS.md
git -C "$repo" commit -q --no-verify -m "docs: onboard this repo"
check_out=$(python3 "$scripts/lib/decisions.py" check "$repo" --base HEAD --label main 2>&1)
expect_exit 0 "$?" "e2e: the gate check passes the seeded log"

# 5. A new session loads the active ones: D4 is superseded by D5.
load_out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/load-decisions.sh" 2>&1)
expect_match '^  D1  Record architecture decisions$' "$load_out" "e2e: the loader lists D1"
expect_match '^  D5  Queue for imports$' "$load_out" "e2e: the loader lists D5"
expect_no_match '^  D4 ' "$load_out" "e2e: the loader drops superseded D4"
expect_match '^5$' "$(printf '%s\n' "$load_out" | wc -l | tr -d ' ')" "e2e: header plus 4 active titles"

# 6. Someone flips the pair by hand: D4 active again, D5 still superseding it.
sed 's/^Status: superseded by D5$/Status: active/' "$repo/DECISIONS.md" >"$work/flipped"
cp "$work/flipped" "$repo/DECISIONS.md"
check_out=$(python3 "$scripts/lib/decisions.py" check "$repo" 2>&1)
expect_exit 1 "$?" "e2e: check refuses a broken supersede pair"
expect_match 'D5 supersedes D4, but D4 does not say "superseded by D5"' "$check_out" "e2e: check names the pair"
