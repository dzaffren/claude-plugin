# One walk through the decision-pr slice: the gate reads the spec's Decided
# alone rows and Review section, render builds the body's first two parts,
# and the attribution hook reads the body file at the path /ship passes. Then
# the gate refuses a row with no Undo, and a spec with no Review section.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

repo=$(mktemp -d -p "$work")
mkdir -p "$repo/docs/specs"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester

spec="$repo/docs/specs/export-csv.md"
cat >"$spec" <<'SPEC'
# Export CSV

**Version:** v1 · **Status:** Built · **Type:** Feature · **Project type:** CLI/Library

| | |
| --- | --- |
| **Rollout** | Flag `export_csv`, off by default. Turn it off to roll back. |
| **Proof it works** | `invoices export --csv ACME-01` writes the file. |

**E2E:** tests/test_export.py

## Review

2026-10-13 · 7 raw findings, 4 survived, 4 fixed.

- A01 Broken Access Control · `routes/export.py:14` · put back `@login_required` on `export_ledger` · `9c1d2e3`

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | Is the CSV comma separated? | question | spec p1 | user | Resolved | Yes, commas. 2026-10-10 |
| O7 | Scenario 3 said "Then the CSV has the columns number, date, total and VAT". The invoices table has no VAT field. | flag | build | user | Decided alone | Chose: drop the VAT column. Other: add a VAT field to invoices. Undo: put back the old scenario 3, and add the field. 2026-10-12 |
| O9 | The diff stored the export rows in SQLite. D7 says "Use Postgres, not SQLite". | flag | review | user | Decided alone | Chose: store the rows in Postgres, as D7 says. Other: supersede D7 through /spec. Undo: git revert 4e1f9a2. 2026-10-13 |
SPEC
cat >"$repo/OVERVIEW.md" <<'OVERVIEW'
# Invoices

**Status:** Active · **Updated:** 2026-10-13 by /ship export-csv

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

gate() {
  gate_out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/verify-ship-gates.sh" docs/specs/export-csv.md 2>&1)
  gate_status=$?
}

run_hook() {   # run_hook <shell command>; sets $hook_status
  local payload
  payload=$(ZUKO_CMD="$1" python3 -c 'import json,os; print(json.dumps({"tool_input":{"command":os.environ["ZUKO_CMD"]}}))')
  printf '%s' "$payload" | (cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/block-attribution.sh") >/dev/null 2>&1
  hook_status=$?
}

# 1. The gate passes and says what it read.
gate
expect_exit 0 "$gate_status" "e2e: the gate passes a spec with complete rows and a Review run"
expect_match '^Decided alone: 2 rows, each with Chose, Other and Undo$' "$gate_out" "e2e: the gate names the rows it checked"
expect_match '^Review: 1 run recorded$' "$gate_out" "e2e: the gate names the runs it read"

# 2. render builds Your call and Review into the body file, word for word.
body="$(git -C "$repo" rev-parse --absolute-git-dir)/zuko-pr-body.md"
python3 "$scripts/lib/pr_body.py" render "$spec" >"$body"
expect_exit 0 "$?" "e2e: render writes the body file"
expect_match '^## Your call$' "$(head -1 "$body")" "e2e: the body starts with Your call"
expect_match '^\| O7 \| Scenario 3 said .* \| drop the VAT column\. \| add a VAT field to invoices\. \| put back the old scenario 3, and add the field\. \|$' "$(cat "$body")" "e2e: O7's parts are copied word for word, date dropped"
expect_match '^\| O9 \| .* \| git revert 4e1f9a2\. \|$' "$(cat "$body")" "e2e: O9's Undo is copied word for word"
expect_match '## Your call ## Review' "$(grep '^## ' "$body" | tr '\n' ' ')" "e2e: Review comes after Your call"
expect_exit 0 "$(git -C "$repo" status --porcelain | wc -l | tr -d ' ')" "e2e: the body file leaves the work tree clean"

# 3. /ship adds its own parts; from ## Review down the body is 300 words or fewer.
cat >>"$body" <<'REST'

## What ships

`invoices export --csv ACME-01` writes the customer's ledger as a CSV file.
The columns are number, date and total.

## Verify by hand

- `pytest tests/test_export.py` gives 14 passed.

## Flag and rollback

Flag `export_csv`, off by default. Rollback: turn the flag off.

Spec: `docs/specs/export-csv.md`
REST
words=$(sed -n '/^## Review$/,$p' "$body" | wc -w | tr -d ' ')
[ "$words" -le 300 ] && record PASS "e2e: the body from ## Review down has $words words" \
  || record FAIL "e2e: the body from ## Review down has 300 words or fewer" "it has $words"

# 4. The attribution hook reads the body file at its literal absolute path.
run_hook "gh pr create --title \"feat(export): add the CSV export of the ledger\" --body-file $body"
expect_exit 0 "$hook_status" "e2e: the hook lets the rendered body through"
cp "$body" "$body.signed"
printf '\nGenerated with Claude Code\n' >>"$body.signed"
run_hook "gh pr create --title \"feat(export): add the CSV export of the ledger\" --body-file $body.signed"
expect_exit 2 "$hook_status" "e2e: the hook reads the body file, so a signed body is blocked"

# 5. A row with no Undo fails the gate, and names the row.
sed -i.bak 's/ Undo: put back the old scenario 3, and add the field\.//' "$spec" && rm -f "$spec.bak"
git -C "$repo" commit -q --no-verify -am "docs(spec): drop the undo"
gate
expect_exit 1 "$gate_status" "e2e: the gate fails a row with no Undo"
expect_match '^- O7  Decided alone row has no "Undo:"$' "$gate_out" "e2e: the gate names O7 and the missing part"
python3 "$scripts/lib/pr_body.py" render "$spec" >/dev/null 2>&1
expect_exit 1 "$?" "e2e: render refuses the same spec, so no body is built from it"

# 6. A spec with no Review section fails the gate, and says what to run.
python3 - "$spec" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read()
start = text.index("## Review\n")
open(path, "w").write(text[:start] + text[text.index("## Open items\n"):])
PY
git -C "$repo" commit -q --no-verify -am "docs(spec): drop the review"
gate
expect_exit 1 "$gate_status" "e2e: the gate fails a spec with no Review section"
expect_match "^- No '## Review' section in the spec\. Run /review on this branch first\.$" "$gate_out" "e2e: the gate says to run /review"
