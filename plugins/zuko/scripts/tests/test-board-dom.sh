# The board page's own script, run in headless Chrome: values from the files
# show as text, the header and the rail show the stage, and a Mermaid classDef
# cannot put HTML outside its diagram (GHSA-ghcm-xqfw-q4vr). A second render
# with --gate draws the gate card: its values show as text, it sits above the
# rail, and it opens the board on the gated slice. The other board
# tests read only the JSON block, so they cannot see what the script draws.
# Skips with a message when Chrome is missing, or when Mermaid does not load
# from the CDN, since then no diagram is drawn and the classDef check proves
# nothing.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

chrome=$(command -v google-chrome || command -v chromium || command -v chromium-browser || true)
if [ -z "$chrome" ]; then
  echo "board-dom: no Chrome on this machine, so the page script is not run" >&2
  record PASS "dom: skipped, no Chrome"
  return 0 2>/dev/null || exit 0
fi

dir=$(mktemp -d -p "$work")
mkdir -p "$dir/docs/specs/dom"
cat >"$dir/docs/specs/dom/shape.md" <<'SHAPE'
# Dom test

**Project type:** CLI/Library · **Status:** Shaped

## Problem

A problem with <img src=x onerror="document.body.dataset.pwned='problem'"> in it.

## Slices

| # | Slice | What ships | Why this order |
| --- | --- | --- | --- |
| 1 | evil | Ships <b id="bold">bold</b> text. | First. |
| 2 | later | Comes later. | Second. |
| 3 | drafty | At pause 3. | Third. |
SHAPE
cat >"$dir/docs/specs/evil.md" <<'SPEC'
# Evil

**Version:** v1 · **Status:** Draft · **Type:** Feature · **Project type:** CLI/Library

**Depends on:** None

Opening with <img src=x onerror="document.body.dataset.pwned='opening'"> in it.

## Flow

```mermaid
flowchart LR
  A[Start] -- goes --> B[End]
```

The flow, read out loud.

## States

```mermaid
stateDiagram-v2
  classDef xss fill:red</style></svg><div id="INJECTED">HACKED</div><svg><style>a:b
  [*] --> A:::xss
```

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | A question? | question | spec p1 | user | Resolved | <img src=x onerror="document.body.dataset.pwned='row'"> 2026-10-26 |
SPEC

python3 "$scripts/lib/board.py" render "$dir/docs/specs/dom/shape.md" --by "/spec evil pause 1" >"$dir/page.html" 2>"$dir/err"
expect_exit 0 "$?" "dom: render exits 0"

dom=$("$chrome" --headless=new --disable-gpu --virtual-time-budget=15000 --dump-dom "file://$dir/page.html" 2>/dev/null)

if ! grep -q '<svg' <<<"$dom"; then
  echo "board-dom: Mermaid did not load from the CDN, so the diagram checks are not run" >&2
  record PASS "dom: diagram checks skipped, Mermaid did not load"
else
  expect_no_match 'id="INJECTED"' "$dom" "dom: a classDef cannot put HTML outside its diagram"
fi
expect_no_match 'data-pwned' "$dom" "dom: no onerror from the files runs"
expect_no_match '<b id="bold">' "$dom" "dom: shape text shows as text, not markup"
expect_match '&lt;img src=x onerror' "$dom" "dom: the opening shows its markup as text"
expect_match 'Awaiting you' "$dom" "dom: the header shows the idea is awaiting you"
expect_match 'class="cur"><span class="node">◈</span><span class="lbl">Pause 1</span>' "$dom" \
  "dom: the rail lights Pause 1 as the current stage"
expect_match 'no spec at docs/specs/later\.md' "$dom" "dom: a slice with no spec says where its spec would be"
expect_match '<section class="gate" id="gate" aria-label="Waiting for you" hidden=""></section>' "$dom" \
  "dom: with no --gate, the gate card is hidden and empty"

# --- the gate card ---
cat >"$dir/docs/specs/drafty.md" <<'SPEC'
# Drafty

**Version:** v1 · **Status:** Draft · **Type:** Feature · **Project type:** CLI/Library

**Depends on:** None

At pause 3.

## Interface

**The card**

## Technical plan

### Decisions to record

```text
## D9 · 2026-10-26 · Draw <i id="ital">this</i> as text
```

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | Is <img src=x onerror="document.body.dataset.pwned='gate'"> text? | question | spec p3 | user | Open | — |
SPEC

python3 "$scripts/lib/board.py" render "$dir/docs/specs/dom/shape.md" --by "/spec drafty pause 3" \
  --gate "$dir/docs/specs/drafty.md" >"$dir/gate.html" 2>"$dir/err"
expect_exit 0 "$?" "gate: render exits 0"
dom=$("$chrome" --headless=new --disable-gpu --virtual-time-budget=15000 --dump-dom "file://$dir/gate.html" 2>/dev/null)

expect_no_match 'data-pwned' "$dom" "gate: no onerror from an Open row runs"
expect_match 'Is &lt;img src=x onerror="document.body.dataset.pwned=.gate."&gt; text\?' "$dom" \
  "gate: the Open row's What shows its markup as text"
expect_no_match '<i id="ital">' "$dom" "gate: a drafted title shows as text, not markup"
expect_match 'To approve with /build:' "$dom" "gate: pause 3 lists the drafted entries to approve"
expect_match 'D9</span><span>Draw &lt;i id="ital"&gt;this&lt;/i&gt; as text' "$dom" "gate: each drafted entry's ID and title"
expect_match '<h2>drafty · Pause 3 · technical and ship plan</h2>' "$dom" "gate: the head names the slice and the pause"
order=$(python3 -c 'import sys
dom = sys.stdin.read()
gate, rail = dom.find("<section class=\"gate\" id=\"gate\""), dom.find("id=\"rail\"")
print("above" if -1 < gate < rail and "hidden" not in dom[gate:dom.index(">", gate)] else "not above")' <<<"$dom")
expect_match '^above$' "$order" "gate: the card shows, above the rail"
expect_match 'class="cur"><span class="node">◈</span><span class="lbl">Pause 3</span>' "$dom" \
  "gate: the card opens the board on the gated slice"
expect_match '<div class="fbody"><span class="fgate">GATE</span><span class="fname">drafty</span>' "$dom" \
  "gate: the gated slice's frame carries the GATE tag"

# --- the hidden gate card takes no space (pr-gate O5) ---
# The page's own .gate rule sets display: grid, which beats the hidden
# attribute unless a rule says otherwise. A probe script reads the computed
# display after the page draws.
sed 's#</body>#<script>document.body.dataset.gateDisplay = getComputedStyle(document.getElementById("gate")).display;</script></body>#' \
  "$dir/page.html" >"$dir/probe.html"
grep -q '</body>' "$dir/page.html" || printf '<script>document.body.dataset.gateDisplay = getComputedStyle(document.getElementById("gate")).display;</script>' >>"$dir/probe.html"
dom=$("$chrome" --headless=new --disable-gpu --virtual-time-budget=15000 --dump-dom "file://$dir/probe.html" 2>/dev/null)
expect_match 'data-gate-display="none"' "$dom" "gate: with no --gate, the hidden card is not drawn"

# --- the PR card ---
mkdir -p "$dir/docs/specs/prc"
cat >"$dir/docs/specs/prc/shape.md" <<'SHAPE'
# PR card test

**Project type:** CLI/Library · **Status:** Shaped

## Slices

| # | Slice | What ships | Why this order |
| --- | --- | --- | --- |
| 1 | built | A built slice. | First. |
SHAPE
cat >"$dir/docs/specs/built.md" <<'SPEC'
# Built

**Version:** v1 · **Status:** Built · **Type:** Feature · **Project type:** CLI/Library

Built and waiting for review.

## Acceptance criteria

```gherkin
Scenario: a <img src=x onerror="document.body.dataset.pwned='scenario'"> name
  Given a
  When b
  Then c

Scenario: nothing names this one
  Given a
  When b
  Then c
```

## Technical plan

### Changes

| File | What changes | Why |
| --- | --- | --- |
| `src/a.py` | A | Scenario 1 |

### Test plan

| Scenario | Test | Command |
| --- | --- | --- |
| 1 named | `test_a.py` | `pytest tests/test_a.py` |

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | The spec did not say the file name. | flag | build | user | Decided alone | Chose: `a.py`. Other: `b.py`. Undo: rename it. 2026-10-26 |
SPEC
python3 "$scripts/lib/board.py" render "$dir/docs/specs/prc/shape.md" --by "/build built" >"$dir/prc.html" 2>"$dir/err"
expect_exit 0 "$?" "pr card: render exits 0"
dom=$("$chrome" --headless=new --disable-gpu --virtual-time-budget=15000 --dump-dom "file://$dir/prc.html" 2>/dev/null)
expect_no_match 'data-pwned' "$dom" "pr card: no onerror from a scenario name runs"
expect_match 'a &lt;img src=x onerror' "$dom" "pr card: a scenario name shows its markup as text"
order=$(python3 -c 'import sys
dom = sys.stdin.read()
lede, card = dom.find("class=\"lede\""), dom.find("class=\"prc\"")
print("under" if -1 < lede < card else "not under")' <<<"$dom")
expect_match '^under$' "$order" "pr card: the card sits under the opening text"
expect_match '<code>test_a.py</code><span class="cmd">pytest tests/test_a.py</span>' "$dom" "pr card: a test shows with its command"
expect_match '<code>src/a.py</code>' "$dom" "pr card: a file shows"
expect_match 'No test named in the Test plan' "$dom" "pr card: the amber note for a scenario with no test"
expect_match 'No file named in Changes' "$dom" "pr card: the amber note for a scenario with no file"
expect_match 'Decided without you · 1' "$dom" "pr card: the Decided alone rows are counted"
expect_match '<span class="k">Chose</span>`a.py`.' "$dom" "pr card: a Decided alone row shows its Chose"

# --- the Replay strip ---
# The page draws DATA.replay as board.py gives it. This test writes its own
# replay into the JSON, so it does not need a git history.
python3 "$scripts/lib/board.py" data "$dir/docs/specs/dom/shape.md" --by "/spec drafty pause 3" >"$dir/dom.json" 2>"$dir/err"
expect_exit 0 "$?" "replay: data exits 0"
with_replay() {        # with_replay <replay JSON> <page>
  python3 - "$scripts/lib" "$dir/dom.json" "$1" "$2" <<'PY'
import json, sys
sys.path.insert(0, sys.argv[1])
import board
data = json.load(open(sys.argv[2]))
data["replay"] = json.loads(sys.argv[3])
open(sys.argv[4], "w").write(open(board.TEMPLATE).read().replace(board.SLOT, board.blob(data), 1))
PY
}
# The dump holds the page's own script, which spells out the strip's texts,
# so the scripts come out before any check.
drawn() {              # drawn <page>
  "$chrome" --headless=new --disable-gpu --virtual-time-budget=15000 --dump-dom "file://$1" 2>/dev/null \
    | python3 -c 'import re, sys; print(re.sub(r"<script.*?</script>", "", sys.stdin.read(), flags=re.S))'
}
with_replay '{"note": null, "steps": [
  {"at": "2026-10-26 09:59", "hash": "aaaa111", "subject": "docs(spec): draft evil pause 1", "pr": null,
   "stages": {"evil": 1, "later": 0, "drafty": 0}, "moved": [{"slice": "evil", "from": 0, "to": 1}],
   "changed": [{"file": "docs/specs/evil.md", "items": [{"kind": "added", "what": "the spec"}]}]},
  {"at": "2026-10-26 10:20", "hash": "bbbb222", "subject": "docs(spec): bump evil status", "pr": 104,
   "stages": {"evil": 1, "later": 0, "drafty": 0}, "moved": [],
   "changed": [{"file": "docs/specs/evil.md", "items": []}]},
  {"at": "2026-10-26 10:56", "hash": "cccc333", "subject": "docs: <img src=x onerror=\"document.body.dataset.pwned=1\"> evil built", "pr": 104,
   "stages": {"evil": 5, "later": 0, "drafty": 3}, "moved": [{"slice": "evil", "from": 1, "to": 5}],
   "changed": [{"file": "docs/specs/evil.md", "items": [{"kind": "resolved", "what": "O1"}]}]}]}' "$dir/replay.html"
dom=$(drawn "$dir/replay.html")
expect_match 'id="rp-count">step 3 of 3<' "$dom" "replay: the board opens on the last step"
expect_match 'id="rp-next" aria-label="Step forward" disabled="">' "$dom" "replay: forward is off at the last step"
expect_no_match 'data-pwned' "$dom" "replay: no onerror from a commit subject runs"
expect_match 'class="rp-subj">docs: &lt;img src=x onerror="document.body.dataset.pwned=1"&gt; evil built<' "$dom" \
  "replay: a commit subject shows its markup as text"
expect_match '2026-10-26 10:56 · cccc333 · from PR #104' "$dom" "replay: the head shows the time, hash and PR"
expect_match '<b>evil</b>: Pause 1 <span class="ar">→</span> Built' "$dom" "replay: the moved line names the slice and both stages"
expect_match 'class="k-pause">drafty · Pause 3<' "$dom" "replay: each slice shows its stage at the step"
expect_match 'Changed since step 2' "$dom" "replay: the changes are since the step before"
expect_match '3 steps · from main, the merged PRs and this branch' "$dom" "replay: the heading counts the steps"
order=$(python3 -c 'import sys
dom = sys.stdin.read()
mapbox, replay = dom.find("class=\"mapbox\""), dom.find("id=\"replay\"")
print("under" if -1 < mapbox < replay else "not under")' <<<"$dom")
expect_match '^under$' "$order" "replay: the strip sits under the slice map"

# A probe script presses back once, as the user would.
{ cat "$dir/replay.html"; printf '<script>document.getElementById("rp-prev").click();</script>'; } >"$dir/back.html"
dom=$(drawn "$dir/back.html")
expect_match 'id="rp-count">step 2 of 3<' "$dom" "replay: back shows the step before"
expect_match 'No slice changed stage\.' "$dom" "replay: a step with no move says so"
expect_match 'Only the Status line changed\.' "$dom" "replay: a file with no item past its Status line says so"
expect_match 'id="rp-next" aria-label="Step forward">' "$dom" "replay: forward is on again"

with_replay '{"steps": [], "note": null}' "$dir/empty.html"
dom=$(drawn "$dir/empty.html")
expect_match 'No commits yet for this idea\. Replay starts after the first commit\.' "$dom" \
  "replay: with no commits, the strip says when replay starts"

with_replay 'null' "$dir/none.html"
dom=$(drawn "$dir/none.html")
expect_no_match 'id="replay"' "$dom" "replay: JSON with no replay draws no strip"
expect_match 'id="map"' "$dom" "replay: with no replay, the rest of the board draws"

# A probe at step 3 reads what the strip draws: the size of each control, and
# the colour of a Not started chip. It then presses back to step 1 from the
# keyboard, and reads where focus went.
{ cat "$dir/replay.html"; cat <<'PROBE'; } >"$dir/rp-probe.html"
<script>
const b = document.body.dataset, box = id => document.getElementById(id).getBoundingClientRect();
b.prev = Math.floor(box("rp-prev").width) + "x" + Math.floor(box("rp-prev").height);
b.next = Math.floor(box("rp-next").width) + "x" + Math.floor(box("rp-next").height);
b.range = String(Math.floor(box("rp-range").height));
b.off = getComputedStyle(document.querySelector(".rp-slices .k-off")).color;
const prev = document.getElementById("rp-prev");
prev.focus(); prev.click(); prev.click();
b.focus = document.activeElement.id || document.activeElement.tagName;
</script>
PROBE
dom=$(drawn "$dir/rp-probe.html")
size() { python3 -c 'import re, sys
m = re.search(r"data-%s=\"(\d+)x(\d+)\"" % sys.argv[1], sys.stdin.read())
print("ok" if m and int(m.group(1)) >= 44 and int(m.group(2)) >= 44 else "small: %s" % (m and m.group(0)))' "$1" <<<"$dom"; }
expect_match '^ok$' "$(size prev)" "replay: back is at least 44 by 44 px"
expect_match '^ok$' "$(size next)" "replay: forward is at least 44 by 44 px"
expect_match 'data-range="(4[4-9]|[5-9][0-9])"' "$dom" "replay: the slider is at least 44 px tall"
expect_match 'data-off="rgb\(138, 143, 156\)"' "$dom" "replay: a Not started chip uses the muted text colour, 5.7:1 on the panel"
expect_match 'data-focus="rp-range"' "$dom" "replay: focus moves to the slider when back turns off"
