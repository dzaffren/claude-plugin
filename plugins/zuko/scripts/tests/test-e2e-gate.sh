# One walk through the gate-card slice in one fixture repo, as the stages run
# it: render the board with --gate, then copy the file to its last-stop copy.
# The shape gate first, then pr-gate at pause 1, a second stop at pause 1
# after a change, pause 2, and pause 2 again with the copy lost. Each step
# reads the gate back from the data block of the rendered page.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

board="$scripts/lib/board.py"
repo=$(mktemp -d -p "$work")
specs="$repo/docs/specs"
pages="$specs/.pages"
shape="$specs/living-board/shape.md"
spec="$specs/pr-gate.md"
mkdir -p "$specs/living-board" "$pages"
today=$(date +%Y-%m-%d)

# stop <file> <by>: render the board at a stop, then copy the file, as
# visual-page.md says. Sets $status.
stop() {
  python3 "$board" render "$shape" --by "$2" --gate "$1" >"$pages/living-board-board.html" 2>"$repo/err"
  status=$?
  case "$1" in
    "$shape") cp "$1" "$pages/living-board-shape-last.md" ;;
    *) cp "$1" "$pages/$(basename "$1" .md)-last.md" ;;
  esac
}

# get <python expression>: G is the gate in the rendered page's data block.
get() {
  python3 -c 'import json, sys
page = open(sys.argv[2], encoding="utf-8").read()
start = page.index(">", page.index("<script id=\"data\"")) + 1
G = json.loads(page[start:page.index("</script>", start)])["gate"]
v = eval(sys.argv[1])
print(v if isinstance(v, str) else json.dumps(v, ensure_ascii=False))' "$1" "$pages/living-board-board.html" 2>/dev/null
}

same() {  # same <expected> <actual> <description>
  if [ "$2" = "$1" ]; then record PASS "$3"
  else record FAIL "$3" "expected [$1], got [$2]"; fi
}

cat >"$shape" <<'SHAPE'
# Living board

**Project type:** CLI/Library · **Status:** Shaped

## Problem

The user approves pauses without following them.

## Slices

| # | Slice | What ships | Why this order |
| --- | --- | --- | --- |
| 1 | idea-board | One page per idea. | The one picture of the idea. Every later slice adds to this page. |
| 2 | gate-card | A gate card at each pause. | Needs the page. |
| 3 | pr-gate | A PR gate card. | Needs the page. |
| 4 | library | The hub page. | Once two boards exist. |
| 5 | replay | Scrub the history. | Last. |

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
SHAPE

# --- scenario 4: /shape stops to ask which slice to spec first ---
stop "$shape" "/shape living-board"
expect_exit 0 "$status" "shape: render exits 0"
same "shape" "$(get 'G["kind"]')" "shape: the card is the shape's"
same '{"name": "idea-board", "why": "The one picture of the idea. Every later slice adds to this page."}' \
  "$(get 'G["recommended"]')" "shape: it names idea-board and why"
same "0 first" "$(get '"%d %s" % (len(G["open"]), G["changed"]["state"])')" "shape: no Open rows, and the first stop"
[ -f "$pages/living-board-shape-last.md" ]
expect_exit 0 "$?" "shape: the copy is kept at living-board-shape-last.md"

# --- scenario 1: pr-gate at pause 1, the first stop ---
cat >"$spec" <<'SPEC'
# PR gate

**Version:** v1 · **Status:** Draft · **Type:** Feature · **Project type:** CLI/Library

**Shape doc:** docs/specs/living-board/shape.md

/ship puts a PR gate card on the board.

## Acceptance criteria

```gherkin
Scenario: the PR card lists each criterion
  Then the card lists each criterion

Scenario: each criterion names its tests
  Then each criterion names a test

Scenario: the PR body links the card
  Then the PR body has the board link

Scenario: a PR from a fork
  Then the card shows for a fork too
```

## Scope

**In:** one PR card for each slice at /ship, PRs from forks too.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | Which PRs get a card? | question | spec p1 | user | Open | — |
| O2 | Does a draft PR count? | question | spec p1 | user | Open | — |
| O3 | Does the card show the diff? | question | spec p1 | user | Open | — |
SPEC
stop "$spec" "/spec pr-gate pause 1"
expect_exit 0 "$status" "pause 1: render exits 0"
same "pause pr-gate 1" "$(get '"%s %s %s" % (G["kind"], G["slice"], G["pause"])')" "pause 1: the card waits on pr-gate at pause 1"
same '["Which PRs get a card?", "Does a draft PR count?", "Does the card show the diff?"]' \
  "$(get '[r["what"] for r in G["open"]]')" "pause 1: the 3 Open rows, each with its question"
same "first" "$(get 'G["changed"]["state"]')" "pause 1: the first stop for this slice"

# --- scenario 3: the user drops the fork scenario, and pause 1 stops again ---
python3 - "$spec" <<'EDIT'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = text.replace("\n\nScenario: a PR from a fork\n  Then the card shows for a fork too", "")
text = text.replace("at /ship, PRs from forks too.", "at /ship. PRs from forks are out of scope.")
open(path, "w", encoding="utf-8").write(text)
EDIT
stop "$spec" "/spec pr-gate pause 1"
same "pause 1, $today" "$(get 'G["changed"]["since"][:-6]')" "change: changed since pause 1, today"
same '[{"kind": "removed", "what": "Scenario: a PR from a fork"}, {"kind": "changed", "what": "Scope"}]' \
  "$(get 'G["changed"]["items"]')" "change: the removed scenario and the changed Scope, and nothing else"

# --- scenario 2: pause 2 adds the Interface, resolves O1 to O3, raises O4 and O5 ---
python3 - "$spec" <<'EDIT'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = text.replace("## Open items", "## Interface\n\n**The card**\n\nAn amber frame.\n\n## Open items")
for n in (1, 2, 3):
    head, row = text.split("| O%d |" % n, 1)
    line, rest = row.split("\n", 1)
    text = head + "| O%d |" % n + line.replace("| Open | — |", "| Resolved | Yes, 2026-10-26 |") + "\n" + rest
text += "| O4 | Which colour? | question | spec p2 | user | Open | — |\n"
text += "| O5 | Does it fit a phone? | flag | spec p2 | user | Open | — |\n"
open(path, "w", encoding="utf-8").write(text)
EDIT
stop "$spec" "/spec pr-gate pause 2"
same "2" "$(get 'G["pause"]')" "pause 2: the card waits at pause 2"
same '[{"pause": 1, "parts": ["the PR card lists each criterion", "each criterion names its tests", "the PR body links the card", "In: one PR card for each slice at /ship. PRs from forks are out of scope."]}]' \
  "$(get 'G["settled"]')" "pause 2: pause 1 settled, with its scenario names and its Scope In line"
same '[{"kind": "added", "what": "Interface"}, {"kind": "new row", "what": "O4, O5"}, {"kind": "resolved", "what": "O1, O2, O3"}]' \
  "$(get 'G["changed"]["items"]')" "pause 2: added Interface, new rows O4 and O5, resolved O1 to O3"

# --- scenario 5: the copy from the last stop is lost ---
rm "$pages/pr-gate-last.md"
stop "$spec" "/spec continue pr-gate pause 2"
same "missing" "$(get 'G["changed"]["state"]')" "no copy: the card says changes cannot be shown"
same '["O4", "O5"] 1 3' "$(get '"%s %d %d" % (json.dumps([r["id"] for r in G["open"]]), len(G["settled"]), G["answered"])')" \
  "no copy: Waiting and Settled show as usual"

# --- /build renders with no --gate, so the card is gone ---
python3 "$board" render "$shape" --by "/build pr-gate" >"$pages/living-board-board.html" 2>"$repo/err"
same "None" "$(get 'str(G)')" "build: a render with no --gate has no card"
