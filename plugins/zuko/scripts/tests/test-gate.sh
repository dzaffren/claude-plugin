# scripts/lib/board.py --gate: the gate card's data. The spec or shape at a
# stop is compared with its copy from the last stop, at
# docs/specs/.pages/<name>-last.md, and the result is the JSON's "gate".
# The rules are in docs/specs/gate-card.md, "How the script builds the gate".
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

board="$scripts/lib/board.py"
repo=$(mktemp -d -p "$work")
specs="$repo/docs/specs"
pages="$specs/.pages"
shape="$specs/living-board/shape.md"
mkdir -p "$specs/living-board" "$pages"

run() {   # run <args...>; sets $out $err $status
  out=$(python3 "$board" "$@" 2>"$repo/err")
  status=$?
  err=$(cat "$repo/err")
}

# pick <python expression>: d is the last $out, G its gate.
pick() {
  python3 -c 'import json, sys
d = json.loads(sys.argv[2])
G = d["gate"]
v = eval(sys.argv[1])
print(v if isinstance(v, str) else json.dumps(v, ensure_ascii=False))' "$1" "$out" 2>/dev/null
}

same() {  # same <expected> <actual> <description>
  if [ "$2" = "$1" ]; then record PASS "$3"
  else record FAIL "$3" "expected [$1], got [$2]"; fi
}

gate() {  # gate <file>: data for the shape with --gate <file>
  run data "$shape" --by "/spec pr-gate" --gate "$1"
}

cat >"$shape" <<'SHAPE'
# Living board

**Project type:** CLI/Library · **Status:** Shaped

## Problem

The user cannot see what waits for them.

## Slices

| # | Slice | What ships | Why this order |
| --- | --- | --- | --- |
| 1 | idea-board | One page per idea. | First. |
| 2 | pr-gate | A PR gate card. | The pain is worst at the PR. |
| 3 | built-one | A built slice. | Third. |

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | Where does the board live? | question | shape | user | Resolved | claude.ai, 2026-10-25 |
| O2 | Which port? | question | shape | user | Accepted risk | 4751, 2026-10-25 |
SHAPE

printf '# Idea board\n\n**Version:** v1 · **Status:** Shipped · **Type:** Feature · **Project type:** CLI/Library\n' >"$specs/idea-board.md"
printf '# Built one\n\n**Version:** v1 · **Status:** Built · **Type:** Feature · **Project type:** CLI/Library\n\n## Technical plan\n\nText.\n' >"$specs/built-one.md"

# The pr-gate spec is built from parts, so each stop changes only what it says.
head_part() {  # head_part <status>
  cat <<HEAD
# PR gate

**Version:** v1 · **Status:** $1 · **Type:** Feature · **Project type:** CLI/Library

**Shape doc:** docs/specs/living-board/shape.md

/ship puts a PR gate card on the board.

HEAD
}

criteria() {  # criteria [fork]: 4 scenarios, a 5th about forks with "fork"
  cat <<'AC'
## Acceptance criteria

```gherkin
Scenario: the PR card lists each criterion
  Given a spec with 4 scenarios
  Then the card lists 4 criteria

Scenario: each criterion names its tests
  Then each criterion names a test

Scenario: a choice made alone shows
  Then the card lists each Decided alone row

Scenario: the PR body links the card
  Then the PR body has the board link
AC
  if [ "${1:-}" = fork ]; then
    cat <<'AC'

Scenario: a PR from a fork
  Then the card shows for a fork too
AC
  fi
  printf '```\n\n'
}

scope() {  # scope <in text>
  cat <<SCOPE
## Scope

**In:** $1

**Out:** replay.

SCOPE
}

interface() {
  cat <<'IFACE'
## Interface

```mermaid
flowchart LR
  A[PR] --> B[card]
```

**The card**

An amber frame.

### The terminal

One line.

IFACE
}

technical() {
  cat <<'TECH'
## Technical plan

### Approach

A script builds the card.

### Decisions to record

```text
## D70 · 2026-10-26 · The PR card reads the spec, not the diff

Why: the spec is the contract.
Source: specs/pr-gate.md
Status: active

## D71 · 2026-10-26 · The card links from the PR body

Why: one click.
Source: specs/pr-gate.md
Status: active
```

TECH
}

ledger() {  # ledger <row>...: the Open items table with these rows
  printf '## Open items\n\n| ID | What | Type | Raised at | Owner | Status | Answer |\n| --- | --- | --- | --- | --- | --- | --- |\n'
  printf '%s\n' "$@"
}

o1_open='| O1 | Which PRs get a card? | question | spec p1 | user | Open | — |'
o2_open='| O2 | Does a draft PR count? | question | spec p1 | user | Open | — |'
o3_open='| O3 | Is the card \| piped? | flag | spec p1 | user | Open | — |'
o1_done='| O1 | Which PRs get a card? | question | spec p1 | user | Resolved | All, 2026-10-26 |'
o2_done='| O2 | Does a draft PR count? | question | spec p1 | user | Resolved | No, 2026-10-26 |'
o3_done='| O3 | Is the card \| piped? | flag | spec p1 | user | Resolved | Yes, 2026-10-26 |'
o4_open='| O4 | Which colour? | question | spec p2 | user | Open | — |'
o5_open='| O5 | Does it show on a phone? | flag | spec p2 | user | Open | — |'

pause1() {  # pause1 [fork] [<in text>] [<status>]
  head_part "${3:-Draft}"
  criteria "${1:-}"
  scope "${2:-one PR card for each slice at /ship.}"
  ledger "$o1_open" "$o2_open" "$o3_open"
}
pause2() {
  head_part Draft; criteria; scope "one PR card for each slice at /ship."; interface
  ledger "$o1_done" "$o2_done" "$o3_done" "$o4_open" "$o5_open"
}
pause3() {
  head_part Draft; criteria; scope "one PR card for each slice at /ship."; interface; technical
  ledger "$o1_done" "$o2_done" "$o3_done" "$o4_open" "$o5_open"
}

copy="$pages/pr-gate-last.md"

# --- scenario 1: the first pause, with no copy ---
pause1 >"$specs/pr-gate.md"
gate "$specs/pr-gate.md"
expect_exit 0 "$status" "pause 1: exits 0"
same "pause pr-gate 1" "$(pick '"%s %s %s" % (G["kind"], G["slice"], G["pause"])')" "pause 1: a pause gate on pr-gate at pause 1"
same '[{"id": "O1", "type": "question", "what": "Which PRs get a card?"}, {"id": "O2", "type": "question", "what": "Does a draft PR count?"}, {"id": "O3", "type": "flag", "what": "Is the card | piped?"}]' \
  "$(pick 'G["open"]')" "pause 1: the 3 Open rows with ID, type and What, an escaped pipe shown as a pipe"
same '[] 0 [] None' "$(pick '"%s %s %s %s" % (G["settled"], G["answered"], G["drafted"], G["recommended"])')" \
  "pause 1: nothing settled, nothing answered, no drafted entries, no recommended slice"
same '{"state": "first", "since": null, "items": []}' "$(pick 'G["changed"]')" "pause 1: no copy is the first stop"

# --- scenario 2: pause 2 against its pause 1 copy ---
pause1 >"$copy"
touch -d "2026-10-26 14:02" "$copy"
pause2 >"$specs/pr-gate.md"
gate "$specs/pr-gate.md"
same "2" "$(pick 'G["pause"]')" "pause 2: the gate is at pause 2"
same '[{"pause": 1, "parts": ["the PR card lists each criterion", "each criterion names its tests", "a choice made alone shows", "the PR body links the card", "In: one PR card for each slice at /ship."]}]' \
  "$(pick 'G["settled"]')" "pause 2: pause 1 settled, with its 4 scenario names and the In line"
same "3" "$(pick 'G["answered"]')" "pause 2: 3 answered rows"
same '["O4", "O5"]' "$(pick '[r["id"] for r in G["open"]]')" "pause 2: the new Open rows wait"
same "diff pause 1, 2026-10-26 14:02" "$(pick 'G["changed"]["state"] + " " + G["changed"]["since"]')" \
  "pause 2: changed since the copy's pause and modified time"
same '[{"kind": "added", "what": "Interface"}, {"kind": "new row", "what": "O4, O5"}, {"kind": "resolved", "what": "O1, O2, O3"}]' \
  "$(pick 'G["changed"]["items"]')" "pause 2: added Interface, new rows O4 and O5, resolved O1 to O3, and nothing else"

# --- pause 3: drafted entries, and pause 2 settled ---
pause2 >"$copy"
pause3 >"$specs/pr-gate.md"
gate "$specs/pr-gate.md"
same "3" "$(pick 'G["pause"]')" "pause 3: the gate is at pause 3"
same '[{"id": "D70", "title": "The PR card reads the spec, not the diff"}, {"id": "D71", "title": "The card links from the PR body"}]' \
  "$(pick 'G["drafted"]')" "pause 3: the drafted D-entries from the fence under Decisions to record"
same '[1, 2]' "$(pick '[p["pause"] for p in G["settled"]]')" "pause 3: pauses 1 and 2 settled"
same '["The card", "The terminal"]' "$(pick 'G["settled"][1]["parts"]')" \
  "pause 3: pause 2's parts are the bold lead-ins and ### headings of Interface, not the fence"
same '[{"kind": "added", "what": "Technical plan"}]' "$(pick 'G["changed"]["items"]')" \
  "pause 3: added Technical plan; the D-entry headings in its fence are not sections"

# --- scenario 3: a change asked at pause 1 ---
pause1 fork "one PR card for each slice at /ship, forks too." >"$copy"
pause1 >"$specs/pr-gate.md"
gate "$specs/pr-gate.md"
same '[{"kind": "removed", "what": "Scenario: a PR from a fork"}, {"kind": "changed", "what": "Scope"}]' \
  "$(pick 'G["changed"]["items"]')" "change: exactly the removed scenario and the changed Scope"

pause1 >"$copy"
touch -d "2026-10-26 14:02" "$copy"
pause1 | sed -e 's/^# PR gate$/# PR gate card/' -e 's/Version:\*\* v1/Version:** v2/' \
  -e 's/^\/ship puts a PR gate card on the board\.$/\/ship puts a card on the board./' >"$specs/pr-gate.md"
gate "$specs/pr-gate.md"
same '{"state": "none", "since": "pause 1, 2026-10-26 14:02", "items": []}' "$(pick 'G["changed"]')" \
  "change: a new title, Version line and opening above the first ## is not a change"

pause1 | sed 's/^  Then each criterion names a test$/  Then   each criterion names a test/' \
  | awk '{ print } /^## Scope$/ { print "" }' >"$specs/pr-gate.md"
gate "$specs/pr-gate.md"
same "none" "$(pick 'G["changed"]["state"]')" "change: squeezed spaces and extra blank lines are not a change"

pause1 | sed 's/^  Then each criterion names a test$/  Then each criterion names two tests/' >"$specs/pr-gate.md"
gate "$specs/pr-gate.md"
same '[{"kind": "changed", "what": "Scenario: each criterion names its tests"}]' "$(pick 'G["changed"]["items"]')" \
  "change: a scenario's body that changed is a changed scenario"

pause1 | sed 's/^| O2 \(.*\)| Open | — |$/| O2 \1| Accepted risk | Fine, 2026-10-26 |/' >"$specs/pr-gate.md"
gate "$specs/pr-gate.md"
same '[{"kind": "accepted risk", "what": "O2"}]' "$(pick 'G["changed"]["items"]')" \
  "change: a row that left Open is tagged with its new Status"

# --- scenario 4: the shape gate ---
gate "$shape"
expect_exit 0 "$status" "shape: exits 0"
same "shape None None" "$(pick '"%s %s %s" % (G["kind"], G["slice"], G["pause"])')" "shape: a shape gate, on no slice"
same '{"name": "pr-gate", "why": "The pain is worst at the PR."}' "$(pick 'G["recommended"]')" \
  "shape: recommends the first slice that is not Shipped, with its Why this order cell"
same '[] 2 []' "$(pick '"%s %s %s" % (G["open"], G["answered"], G["settled"])')" \
  "shape: no Open rows, its 2 rows that are not Open answered, nothing settled"
same "first" "$(pick 'G["changed"]["state"]')" "shape: no copy is the first stop"
cp "$shape" "$pages/living-board-shape-last.md"
touch -d "2026-10-26 09:30" "$pages/living-board-shape-last.md"
sed -i 's/^| 3 | built-one | A built slice. | Third. |$/| 3 | built-one | A built slice, renamed. | Third. |/' "$shape"
gate "$shape"
same '{"state": "diff", "since": "the last stop, 2026-10-26 09:30", "items": [{"kind": "changed", "what": "Slices"}]}' \
  "$(pick 'G["changed"]')" "shape: the copy at <idea>-shape-last.md is compared, and since names its time"

# --- scenario 5: no copy at pause 2 ---
rm -f "$copy"
pause2 >"$specs/pr-gate.md"
gate "$specs/pr-gate.md"
same '{"state": "missing", "since": null, "items": []}' "$(pick 'G["changed"]')" "no copy: missing at pause 2"
same "1 3" "$(pick '"%s %s" % (len(G["settled"]), G["answered"])')" "no copy: Waiting and Settled as usual"

# --- no card ---
run data "$shape" --by "/build pr-gate"
same "null" "$(pick 'd["gate"]')" "no card: no --gate is a null gate"
gate "$specs/built-one.md"
expect_exit 0 "$status" "no card: a Built spec exits 0"
same "null" "$(pick 'd["gate"]')" "no card: --gate on a Built spec is a null gate"
cp "$specs/pr-gate.md" "$repo/elsewhere.md"
gate "$repo/elsewhere.md"
same "null" "$(pick 'd["gate"]')" "no card: a spec that is not a slice of the shape is a null gate"

# --- refusals and usage ---
gate "$specs/absent.md"
expect_exit 2 "$status" "refuse: a --gate file that cannot be read exits 2"
expect_match "absent.md" "$err" "refuse: the message names the --gate file"
same "" "$out" "refuse: nothing on stdout"
run data "$shape" --by x --gate
expect_exit 2 "$status" "usage: --gate with no file exits 2"
expect_match "--gate <file>" "$err" "usage: the usage names --gate"
run data "$shape" --by x --gat "$shape"
expect_exit 2 "$status" "usage: a misspelt --gate exits 2"

# --- render: the gate reaches the page's data block ---
run render "$shape" --by x --gate "$shape"
expect_exit 0 "$status" "render: exits 0 with --gate"
expect_match '"gate": \{"kind": "shape"' "$out" "render: the data block carries the gate"
