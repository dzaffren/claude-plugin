# scripts/lib/pr_body.py -- check reads the Decided alone rows and the Review
# section for the ship gate; render prints the PR body's Your call and Review
# parts from the same parse.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

pr_body="$scripts/lib/pr_body.py"
dir=$(mktemp -d -p "$work")

o7='| O7 | Scenario 3 said "Then the CSV has the columns number, date, total and VAT". The invoices table has no VAT field. | flag | build | user | Decided alone | Chose: drop the VAT column. Other: add a VAT field to invoices. Undo: put back the old scenario 3, and add the field. 2026-10-12 |'
o9='| O9 | The diff stored the export rows in SQLite. D7 says "Use Postgres, not SQLite". | flag | review | user | Decided alone | Chose: store the rows in Postgres, as D7 says. Other: supersede D7 through /spec. Undo: git revert 4e1f9a2. 2026-10-13 |'
resolved='| O1 | Is the CSV comma separated? | question | spec p1 | user | Resolved | Yes, commas. 2026-10-10 |'
run1='2026-10-13 · 7 raw findings, 4 survived, 4 fixed.'
fix1='- A01 Broken Access Control · `routes/export.py:14` · put back `@login_required` on `export_ledger` · `9c1d2e3`'

# write_spec <name> <review block or "-" for none> <ledger rows...>
write_spec() {
  local name=$1 review=$2 row
  shift 2
  {
    echo "# Export CSV"
    echo ""
    echo "**Version:** v1 · **Status:** Built · **Type:** Feature · **Project type:** CLI/Library"
    echo ""
    if [ "$review" != "-" ]; then
      echo "## Review"
      echo ""
      printf '%s\n' "$review"
      echo ""
    fi
    echo "## Open items"
    echo ""
    echo "| ID | What | Type | Raised at | Owner | Status | Answer |"
    echo "| --- | --- | --- | --- | --- | --- | --- |"
    for row in "$@"; do printf '%s\n' "$row"; done
    echo ""
    echo "## Glossary"
  } >"$dir/$name.md"
}

run() {   # run <command> <name>; sets $out $err $status
  out=$(python3 "$pr_body" "$1" "$dir/$2.md" 2>"$dir/err")
  status=$?
  err=$(cat "$dir/err")
}

# --- check: a pass reports what it read ---
write_spec two "$run1
$fix1" "$resolved" "$o7" "$o9"
run check two
expect_exit 0 "$status" "check: two complete rows and a run pass"
expect_match '^Decided alone: 2 rows, each with Chose, Other and Undo$' "$out" "check: the pass names the row count"
expect_match '^Review: 1 run recorded$' "$out" "check: the pass names the run count"

write_spec one "$run1" "$o7"
run check one
expect_match '^Decided alone: 1 row, with Chose, Other and Undo$' "$out" "check: one row reads as one row"

write_spec none "$run1" "$resolved"
run check none
expect_exit 0 "$status" "check: a spec with no Decided alone row passes"
expect_match '^Decided alone: no rows$' "$out" "check: no rows is still a visible result"

write_spec runs "$run1
$fix1

2026-10-14 · 3 raw findings, 0 survived. Clean." "$o7"
run check runs
expect_match '^Review: 2 runs recorded$' "$out" "check: each dated line is one run"

# --- check: each missing part is named ---
write_spec no-undo "$run1" "${o7/ Undo: put back the old scenario 3, and add the field./}"
run check no-undo
expect_exit 1 "$status" "check: a row with no Undo fails"
expect_match '^O7  Decided alone row has no "Undo:"$' "$out" "check: names the row and the missing Undo"

write_spec no-other-undo "$run1" '| O9 | Stored rows in SQLite. | flag | review | user | Decided alone | Chose: store the rows in Postgres. 2026-10-13 |'
run check no-other-undo
expect_match '^O9  Decided alone row has no "Other:" and no "Undo:"$' "$out" "check: names two missing parts in one line"

write_spec no-parts "$run1" '| O4 | Dropped the VAT column. | flag | build | user | Decided alone | Dropped it. 2026-10-12 |'
run check no-parts
expect_match '^O4  Decided alone row has no "Chose:", no "Other:" and no "Undo:"$' "$out" "check: names all three missing parts"

write_spec empty-undo "$run1" '| O7 | Dropped VAT. | flag | build | user | Decided alone | Chose: drop the VAT column. Other: add a VAT field to invoices. Undo: 2026-10-13 |'
run check empty-undo
expect_exit 1 "$status" "check: an Undo with only a date fails"
expect_match '^O7  Decided alone row has an empty "Undo:"$' "$out" "check: names the empty Undo"
run render empty-undo
expect_exit 1 "$status" "render: a row with an empty part does not render"

write_spec empty-two "$run1" '| O9 | Stored rows in SQLite. | flag | review | user | Decided alone | Chose: Other: Undo: git revert 4e1f9a2. 2026-10-13 |'
run check empty-two
expect_match '^O9  Decided alone row has an empty "Chose:" and an empty "Other:"$' "$out" "check: names two empty parts in one line"

write_spec only-decided "$run1" '| O1 | A question. | question | spec p1 | user | Resolved | Yes. |' '| O2 | A risk. | flag | spec p3 | user | Accepted risk | Off-peak, 2026-10-10 |'
run check only-decided
expect_exit 0 "$status" "check: only Decided alone rows need the three parts"

write_spec padded "$run1" '| O7 | Dropped VAT. | flag | build | user |  Decided alone  | Dropped it. |'
run check padded
expect_exit 1 "$status" "check: a Status cell with spaces around it is still Decided alone"

write_spec escaped "$run1" '| O7 | Scenario 3 said "total \| VAT". | flag | build | user | Decided alone | Chose: drop VAT. Other: add VAT. Undo: put it back. 2026-10-12 |'
run check escaped
expect_exit 0 "$status" "check: an escaped pipe in What does not split the cells"

# --- check: the Review section ---
write_spec no-review - "$o7"
run check no-review
expect_exit 1 "$status" "check: no Review section fails"
expect_match "^No '## Review' section in the spec\. Run /review on this branch first\.$" "$out" "check: no Review section says what to run"

write_spec empty-review "- a line that is not a run" "$o7"
run check empty-review
expect_exit 1 "$status" "check: a Review section with no run line fails"
expect_match "^The '## Review' section has no run line\. Run /review on this branch first\.$" "$out" "check: no run line says what to run"

# --- check: fenced examples are not the spec's own ---
# fenced_example <name>: appends an Interface section whose examples hold a
# Review heading, a run line, and an Open items heading over a Decided alone
# row with no parts.
fenced_example() {
  cat >>"$dir/$1.md" <<'FENCED'

## Interface

`````text
````markdown
## Review

2026-10-13 · 1 raw finding, 0 survived. Clean.
````
`````

```markdown
## Open items

| O8 | An example row. | flag | build | user | Decided alone | Dropped it. |
```
FENCED
}

write_spec fenced "$run1" "$o7"
fenced_example fenced
run check fenced
expect_exit 0 "$status" "check: a row inside a fence is not read"
expect_match '^Decided alone: 1 row' "$out" "check: the scope line counts only the ledger's own rows"
expect_match '^Review: 1 run recorded$' "$out" "check: a run line inside a fence is not counted"

write_spec fenced-only - "$o7"
fenced_example fenced-only
run check fenced-only
expect_match "^No '## Review' section in the spec\." "$out" "check: a Review heading inside nested fences is not read"

# A fence directly under the spec's own headings is still an example.
write_spec fenced-in-ledger "$run1" "$o7"
python3 - "$dir/fenced-in-ledger.md" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read()
example = "```markdown\n| O8 | An example row. | flag | build | user | Decided alone | Dropped it. |\n```\n\n"
open(path, "w").write(text.replace("## Glossary", example + "## Glossary"))
PY
run check fenced-in-ledger
expect_exit 0 "$status" "check: a fenced row under ## Open items is not read"
expect_match '^Decided alone: 1 row' "$out" "check: a fenced row under ## Open items is not counted"
run render fenced-in-ledger
expect_no_match 'O8' "$out" "render: a fenced row under ## Open items is not in Your call"

write_spec fenced-run '```text
2026-10-13 · 1 raw finding, 0 survived. Clean.
```' "$o7"
run check fenced-run
expect_exit 1 "$status" "check: a Review whose only run line is fenced fails"
expect_match "^The '## Review' section has no run line\." "$out" "check: a fenced run line is not a run"

printf '# Export CSV\n\n## Review\n\n%s\n' "$run1" >"$dir/no-ledger.md"
run check no-ledger
expect_exit 1 "$status" "check: a spec with no ledger fails"
expect_match "^No '## Open items' section in the spec\.$" "$out" "check: no ledger is a problem, not a pass"

# --- check: usage and unreadable specs ---
python3 "$pr_body" check "$dir/missing.md" >"$dir/out" 2>"$dir/err"
expect_exit 2 "$?" "check: a spec that does not exist exits 2"
expect_match 'missing\.md' "$(cat "$dir/err")" "check: the error names the file"
python3 "$pr_body" >/dev/null 2>&1
expect_exit 2 "$?" "usage: no arguments exit 2"
python3 "$pr_body" publish "$dir/two.md" >/dev/null 2>&1
expect_exit 2 "$?" "usage: an unknown command exits 2"

# --- render: the exact text ---
expected_two=$(cat <<'BODY'
## Your call

2 things were decided without you. Each one can be undone.

| ID | What | Chose | Other | Undo |
| --- | --- | --- | --- | --- |
| O7 | Scenario 3 said "Then the CSV has the columns number, date, total and VAT". The invoices table has no VAT field. | drop the VAT column. | add a VAT field to invoices. | put back the old scenario 3, and add the field. |
| O9 | The diff stored the export rows in SQLite. D7 says "Use Postgres, not SQLite". | store the rows in Postgres, as D7 says. | supersede D7 through /spec. | git revert 4e1f9a2. |

## Review

2026-10-13 · 7 raw findings, 4 survived, 4 fixed.
- A01 Broken Access Control · `routes/export.py:14` · put back `@login_required` on `export_ledger` · `9c1d2e3`
BODY
)
run render two
expect_exit 0 "$status" "render: a passing spec renders"
if [ "$out" = "$expected_two" ]; then record PASS "render: two rows give the exact table and the Review lines"
else record FAIL "render: two rows give the exact table and the Review lines" "$(diff <(printf '%s\n' "$expected_two") <(printf '%s\n' "$out") | head -10)"; fi

run render one
expect_match '^1 thing was decided without you\. It can be undone\.$' "$out" "render: one row reads as one thing"

run render none
expected_none=$(printf '## Your call\n\nNothing was decided without you.\n\n## Review\n\n%s' "$run1")
if [ "$out" = "$expected_none" ]; then record PASS "render: no row gives the one line and no table"
else record FAIL "render: no row gives the one line and no table" "$(diff <(printf '%s\n' "$expected_none") <(printf '%s\n' "$out") | head -10)"; fi

run render runs
expect_match "$(printf '%s' "$run1" | sed 's/[.]/\\./g').*2026-10-14 · 3 raw findings, 0 survived\. Clean\." "$(tr '\n' ' ' <<<"$out")" "render: two runs stay in order"
expect_match '^$' "$(sed -n '/9c1d2e3/{n;p;}' <<<"$out")" "render: a blank line between runs is kept"

run render escaped
expect_match '^\| O7 \| Scenario 3 said "total \\\| VAT"\. \| drop VAT\. \| add VAT\. \| put it back\. \|$' "$out" "render: an escaped pipe stays escaped"

run render no-undo
expect_exit 1 "$status" "render: a failing spec does not render"
expect_match '^$' "$out" "render: nothing on stdout when the check fails"
expect_match 'O7  Decided alone row has no "Undo:"' "$err" "render: the problems go to stderr"
