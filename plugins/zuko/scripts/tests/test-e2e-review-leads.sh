# One walk through the leads that /review could not settle. The reviewer
# writes a LEAD block, /review sends it blind and reports the ones that hold,
# and /ship lets a lead line with no commit through. Then a spec with a run
# line, a fix line and a lead line passes the ship gate, and render copies the
# lead line into the PR body word for word.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

zuko=$(dirname "$scripts")
reviewer="$zuko/agents/reviewer.md"
verifier="$zuko/agents/finding-verifier.md"
review="$zuko/skills/review/SKILL.md"
ship="$zuko/skills/ship/SKILL.md"

squeezed() { [ -f "$1" ] && tr '\n' ' ' <"$1" | tr -s ' ' || echo "(missing: $1)"; }

# 1. The reviewer writes a LEAD block (scenario 1).
reviewer_text=$(cat "$reviewer")
reviewer_flat=$(squeezed "$reviewer")
expect_match '^LEAD: \{one sentence, the possible defect only\}$' "$reviewer_text" "reviewer: the LEAD template starts with the claim"
expect_match '^CATEGORY: \{A0N:2025 name, or correctness\}$' "$reviewer_text" "reviewer: a lead is security or correctness only"
expect_match '^CHANGE: \{added, deleted, or caller\}$' "$reviewer_text" "reviewer: the LEAD template keeps CHANGE"
expect_match '^TRACE: \{the input, then each file:line it passes, to the line where harm would happen\}$' "$reviewer_text" "reviewer: the LEAD template has TRACE"
expect_match '^UNKNOWN: \{the one fact that decides it, which no command the review can run will show\}$' "$reviewer_text" "reviewer: the LEAD template has UNKNOWN"
expect_match '^CHECK: \{a safe check the user can run to settle the fact\}$' "$reviewer_text" "reviewer: the LEAD template has CHECK"
lead_template=$(awk '/^LEAD: \{/ { f = 1 } f && /^```/ { exit } f' "$reviewer")
expect_no_match '^(SEVERITY|RAISED|FAILING CASE): ' "$lead_template" "reviewer: the LEAD template has no SEVERITY, RAISED or FAILING CASE"
expect_match '^FILE: plugins/zuko/scripts/lib/program\.py:41$' "$reviewer_text" "reviewer: the LEAD example is the Windows-only branch of argv"
expect_match 'A lead has exactly one `UNKNOWN`\.' "$reviewer_flat" "reviewer: a lead has exactly one UNKNOWN"
expect_match 'A lead is never a finding with its proof left out\.' "$reviewer_flat" "reviewer: a provable lead is a finding"
expect_match 'A lead that is out of turns, or that needs more reading, is not a lead\.' "$reviewer_flat" "reviewer: an unfinished trace is not a lead"
expect_match 'A coverage, quality or decisions finding is never a lead\.' "$reviewer_flat" "reviewer: only security and correctness can be leads"
expect_match 'Never put a `\|` in `LEAD` or `UNKNOWN`\.' "$reviewer_flat" "reviewer: no pipe in LEAD or UNKNOWN"

# 2. /review sends each lead blind, reports the ones that hold, and never
# fixes one (scenarios 1, 2 and 4). The verifier keeps its lead rules.
review_flat=$(squeezed "$review")
expect_match 'Send each lead to its own `finding-verifier`, with `KIND: lead` first: `KIND: lead`, the `LEAD` claim, `CATEGORY`, `FILE`, `SYMBOL`, `SNIPPET`, `CHANGE`, `EVIDENCE`, `TRACE`, `UNKNOWN` and `BASE`\. Never send `CHECK`\.' \
  "$review_flat" "review: a lead goes to the verifier without its CHECK"
expect_match 'A lead holds when the vote that keeps a finding keeps it\. Drop each other lead\.' "$review_flat" "review: a lead uses the finding vote, and the rest drop"
expect_match 'Findings   5 raw, 2 survived · 1 lead needs validation' "$(cat "$review")" "review: the Findings line counts the leads"
expect_match 'Needs validation   1 lead, not fixed, does not block /ship' "$(cat "$review")" "review: the Needs validation part"
expect_match 'Never fix a lead\.' "$review_flat" "review: a lead is never fixed"
expect_match 'The repo does not answer the `UNKNOWN`' "$(squeezed "$verifier")" "verifier: a lead the repo settles is rejected"

# 3. The Review section gets a lead line with no commit, and /ship accepts it
# (scenario 3).
expect_match 'A lead line has four parts: `needs validation`, `file:line`, the `UNKNOWN` and the `CHECK`\. It has no commit\.' \
  "$review_flat" "review: the four parts of a lead line"
expect_match '`3 raw findings, 0 survived, 1 lead needs validation\.`' "$review_flat" "review: a run with only a lead is not Clean"
expect_match '\| Review done +\| The gate found the spec.s `## Review` section\. Each fix line names a commit on this branch\. A needs validation line names none\. +\|' \
  "$(squeezed "$ship")" "ship gates: a needs validation line names no commit"

# 4. A spec with a lead line passes the ship gate, and render copies the line.
repo=$(mktemp -d -p "$work")
mkdir -p "$repo/docs/specs"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester

lead_line='- needs validation · `plugins/zuko/scripts/lib/program.py:41` · whether PATHEXT on Windows lists .EXE in upper case · in Git Bash on Windows, run `cmd //c echo %PATHEXT%`'
spec="$repo/docs/specs/export-csv.md"
cat >"$spec" <<SPEC
# Export CSV

**Version:** v1 · **Status:** Built · **Type:** Feature · **Project type:** CLI/Library

| | |
| --- | --- |
| **Rollout** | Flag \`export_csv\`, off by default. Turn it off to roll back. |
| **Proof it works** | \`invoices export --csv ACME-01\` writes the file. |

**E2E:** tests/test_export.py

## Review

2026-11-12 · 5 raw findings, 2 survived, 2 fixed, 1 lead needs validation.

- A05 Injection · \`exporters/ledger.py:31\` · call db.run with customer as a parameter · \`9c1d2e3\`
- correctness · \`exporters/ledger.py:52\` · close the file on an empty ledger · \`e02b9f6\`
$lead_line

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | Is the CSV comma separated? | question | spec p1 | user | Resolved | Yes, commas. 2026-10-10 |
SPEC
cat >"$repo/OVERVIEW.md" <<'OVERVIEW'
# Invoices

**Status:** Active · **Updated:** 2026-11-12 by /ship export-csv

Turns a folder of supplier invoices into one ledger CSV.

## Run it

| Task | Command                    |
| ---- | -------------------------- |
| test | `pytest`                   |

## Slices

| Slice      | Status | What it does                  | Page |
| ---------- | ------ | ----------------------------- | ---- |
| export-csv | Built  | Exports a customer's ledger   | —    |
OVERVIEW
cat >"$repo/DECISIONS.md" <<'DECISIONS'
# Decisions

Append-only. A changed decision is a new entry that supersedes the old one; only an
old entry's Status line ever changes.
DECISIONS
python3 "$scripts/lib/changelog.py" init "$repo" >/dev/null
printf '# Invoices\n\n<!-- zuko:start — generated from OVERVIEW.md; edit that file, not this block -->\n<!-- zuko:end -->\n' >"$repo/README.md"
CLAUDE_PROJECT_DIR="$repo" bash "$scripts/render-readme-block.sh" --write 2>/dev/null
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "chore(spec): add the export-csv spec"
git -C "$repo" checkout -q -b feat/export-csv
printf '\n### Added\n\n- `invoices export --csv` writes a customer ledger as CSV.\n' >>"$repo/CHANGELOG.md"
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "feat(export): add the CSV export of the ledger"

gate_out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/verify-ship-gates.sh" docs/specs/export-csv.md 2>&1)
expect_exit 0 "$?" "e2e: the ship gate passes a Review section with a lead line"
expect_match '^Review: 1 run recorded$' "$gate_out" "e2e: the gate reads the run line"

body="$(git -C "$repo" rev-parse --absolute-git-dir)/zuko-pr-body.md"
python3 "$scripts/lib/pr_body.py" render "$spec" >"$body"
expect_exit 0 "$?" "e2e: render writes the body file"
grep -qxF -- "$lead_line" "$body"
expect_exit 0 "$?" "e2e: the body has the lead line word for word"
lead_at=$(grep -nF -- '- needs validation · ' "$body" | cut -d: -f1)
fix_at=$(grep -nF -- '- correctness · ' "$body" | cut -d: -f1)
[ -n "$lead_at" ] && [ -n "$fix_at" ] && [ "$fix_at" -lt "$lead_at" ]
expect_exit 0 "$?" "e2e: the lead line comes after the fix lines"
