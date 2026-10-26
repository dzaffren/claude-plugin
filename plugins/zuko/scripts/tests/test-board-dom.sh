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
