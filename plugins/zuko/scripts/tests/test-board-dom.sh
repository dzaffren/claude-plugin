# The board page's own script, run in headless Chrome: values from the files
# show as text, the header and the rail show the stage, and a Mermaid classDef
# cannot put HTML outside its diagram (GHSA-ghcm-xqfw-q4vr). The other board
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
