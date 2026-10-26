# scripts/lib/board.py: the PR card's data. For a slice at Built or later,
# each scenario gets the tests its Test plan rows name and the files its
# Changes rows name, and the card lists the Decided alone rows. The rules are
# in docs/specs/pr-gate.md, "How the script builds the proof".
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

board="$scripts/lib/board.py"
repo=$(mktemp -d -p "$work")
specs="$repo/docs/specs"
shape="$specs/living-board/shape.md"
mkdir -p "$specs/living-board"

# pick <python expression>: P is the proof of the slice "export".
pick() {
  python3 "$board" data "$shape" --by test 2>/dev/null | python3 -c 'import json, sys
d = json.load(sys.stdin)
P = next(s for s in d["slices"] if s["name"] == "export")["proof"]
v = eval(sys.argv[1])
print(v if isinstance(v, str) else json.dumps(v, ensure_ascii=False))' "$1" 2>/dev/null
}

same() {  # same <expected> <actual> <description>
  if [ "$2" = "$1" ]; then record PASS "$3"
  else record FAIL "$3" "expected [$1], got [$2]"; fi
}

cat >"$shape" <<'SHAPE'
# Living board

**Project type:** CLI/Library · **Status:** Shaped

## Slices

| # | Slice | What ships | Why this order |
| --- | --- | --- | --- |
| 1 | export | A CSV export. | First. |
SHAPE

spec() {  # spec <status>
  cat >"$specs/export.md" <<SPEC
# Export

**Version:** v1 · **Status:** $1 · **Type:** Feature · **Project type:** CLI/Library

Exports the ledger as CSV.

## Acceptance criteria

\`\`\`gherkin
Scenario: the ledger exports as CSV
  Given a ledger
  When the user exports it
  Then a CSV is written

Scenario: an empty ledger
  Given no rows
  When the user exports
  Then the CSV has a header only

Scenario: a <img src=x onerror=alert(1)> name
  Given odd text
  When it exports
  Then it is quoted

Scenario: no test and no file
  Given nothing names it
  When the board renders
  Then the lists are empty

Scenario: a later one
  Given more
  When more
  Then more
\`\`\`

## Technical plan

### Changes

| File | What changes | Why |
| --- | --- | --- |
| \`src/export.py:42\` | Writes rows | Scenarios 1, 2 and 5 |
| \`src/export.py\` | Header | Scenario 2 |
| \`src/cli.py:7\` | \`run|data\` flag | Scenarios 1 to 3 |
| \`src/quote.py\` | Quotes | The Interface section |
| \`src/cli.py:10-20\` | A range | Scenario 1 |
| \`src/dash.py\` | Dashes | scenarios 2–3 |

### Test plan

| Scenario | Test | Command |
| --- | --- | --- |
| 1 exports | \`test_export.py\`: writes a file | \`pytest tests/test_export.py\` |
| 2 empty | \`test_empty.py\` | \`pytest tests/test_empty.py\` |
| 3 quoting | \`test_quote.py\` | \`pytest tests/test_quote.py\` |
| 5 later | \`test_later.py\` | \`pytest tests/test_later.py\` |
| 2–3 (dash) | \`test_dash.py\` | \`pytest tests/test_dash.py\` |
| The page | \`test_page.py\` | \`pytest tests/test_page.py\` |

**E2E:** none.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | Which delimiter? | question | spec p1 | user | Resolved | A comma, 2026-10-26 |
| O2 | The spec did not say the file name. | flag | build | user | Decided alone | Chose: \`ledger.csv\`. Other: a dated name. Undo: rename it in \`src/export.py\`. 2026-10-26 |
SPEC
}

# --- scenario 1: a Built spec gets a card, one row per scenario ---
spec Built
same "5" "$(pick 'len(P["rows"])')" "proof: one row per scenario"
same '[1, "the ledger exports as CSV"]' "$(pick '[P["rows"][0]["n"], P["rows"][0]["name"]]')" "proof: rows are numbered in order and named"
same '[{"test": "test_export.py: writes a file", "command": "pytest tests/test_export.py"}]' "$(pick 'P["rows"][0]["tests"]')" \
  "proof: a Test plan row joins the scenario its first cell starts with, backticks taken off"
same '["src/export.py", "src/cli.py"]' "$(pick 'P["rows"][0]["files"]')" \
  "proof: files from Why cells in table order, line numbers and ranges such as :10-20 taken off, once each; a | inside backticks keeps the Why cell"
same '["src/export.py", "src/cli.py", "src/dash.py"]' "$(pick 'P["rows"][1]["files"]')" "proof: 'Scenarios 1 to 3', 'Scenario 2' and 'scenarios 2–3' all reach scenario 2"
same '["test_quote.py", "test_dash.py"]' "$(pick '[t["test"] for t in P["rows"][2]["tests"]]')" "proof: a Test plan row '2–3 (dash)' reaches scenario 3"
same '["src/export.py"]' "$(pick 'P["rows"][4]["files"]')" "proof: '1, 2 and 5' reaches scenario 5"
same '[{"id": "O2", "what": "The spec did not say the file name.", "chose": "`ledger.csv`.", "undo": "rename it in `src/export.py`."}]' \
  "$(pick 'P["alone"]')" "proof: the Decided alone rows with Chose and Undo, the date taken off"

# --- scenarios 3 and 4: a scenario no test or file names ---
same '[]' "$(pick 'P["rows"][3]["tests"]')" "proof: a scenario no Test plan row names has no tests"
same '[]' "$(pick 'P["rows"][3]["files"]')" "proof: a scenario no Why cell names has no files"

# --- the stage ---
for status in Shipped; do
  spec "$status"
  same "5" "$(pick 'len(P["rows"])')" "proof: a $status spec has a card"
done
spec Refined
same "null" "$(pick 'P')" "proof: a Refined spec has no card"
spec Draft
same "null" "$(pick 'P')" "proof: a Draft spec has no card"
