# One walk through the idea-board slice: a fixture idea with one shipped
# slice (one D-entry, three answered rows), one at pause 1 and one with no
# spec. board.py renders the page; scenarios 1 to 4 are read from the JSON in
# the page, then board.py serve serves it for scenario 5.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

board="$scripts/lib/board.py"
repo=$(mktemp -d -p "$work")
mkdir -p "$repo/docs/specs/living-board" "$repo/docs/specs/.pages"

cat >"$repo/docs/specs/living-board/shape.md" <<'SHAPE'
# Living board

**Project type:** CLI/Library · **Status:** Shaped

## Problem

After a few specs the user cannot recall how the slices connect.

## Slices

```mermaid
flowchart LR
  B[1 idea-board] --> G[2 gate-card]
  B --> P[3 pr-gate]
```

| # | Slice | What ships | Why this order |
| --- | --- | --- | --- |
| 1 | idea-board | One page per idea. | First. |
| 2 | gate-card | A gate card at each pause. | Needs the page. |
| 3 | pr-gate | A PR gate card. | Needs the page. |

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
SHAPE

cat >"$repo/docs/specs/idea-board.md" <<'SPEC'
# Idea board

**Version:** v1 · **Status:** Shipped · **Type:** Feature · **Project type:** CLI/Library

**Shape doc:** docs/specs/living-board/shape.md
**Depends on:** None

Each idea gets one claude.ai page.

## Flow

```mermaid
flowchart LR
  ST[stage ends] -- reads --> F[files]
```

At the end of each stage, the stage builds the board.

## States

```mermaid
stateDiagram-v2
  [*] --> NotStarted
```

One slice moves through these stages.

## Review

2026-10-26 · 3 raw findings, 1 survived, 1 fixed.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | What counts as why? | question | spec p1 | user | Resolved | The D-entries, 2026-10-25 |
| O2 | Is a minute per stage fine? | question | spec p3 | user | Accepted risk | Yes, 2026-10-25 |
| O3 | Which port? | flag | build | user | Decided alone | Chose: 4751. Other: a free port. Undo: change PORT. 2026-10-26 |
| O4 | Still open? | question | spec p3 | user | Open | — |
SPEC

cat >"$repo/docs/specs/gate-card.md" <<'SPEC'
# Gate card

**Version:** v1 · **Status:** Draft · **Type:** Feature · **Project type:** CLI/Library

**Shape doc:** docs/specs/living-board/shape.md
**Depends on:** `idea-board` — the board to hang the card on

At each pause the board shows a gate card.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
SPEC

cat >"$repo/DECISIONS.md" <<'DECISIONS'
# Decisions

## D62 · 2026-10-25 · A script renders the idea board; Claude only publishes it

Why: the board must look the same after every stage.
Rejected: Claude writes the HTML at each stage (the page changes from run to run,
and no test can check it), Claude edits the last page (it drifts from the files).
Source: specs/idea-board.md
Status: active
DECISIONS

page="$repo/docs/specs/.pages/living-board-board.html"
python3 "$board" render "$repo/docs/specs/living-board/shape.md" --by "/review idea-board" >"$page" 2>"$work/render.err"
expect_exit 0 "$?" "render: exits 0"

# get <python expression>: d is the board read back from the page's data
# block, S its slices by name.
get() {
  python3 -c 'import json, sys
page = open(sys.argv[2], encoding="utf-8").read()
start = page.index(">", page.index("<script id=\"data\"")) + 1
d = json.loads(page[start:page.index("</script>", start)])
S = {s["name"]: s for s in d["slices"]}
v = eval(sys.argv[1])
print(v if isinstance(v, str) else json.dumps(v, ensure_ascii=False))' "$1" "$page" 2>/dev/null
}

same() {  # same <expected> <actual> <description>
  if [ "$2" = "$1" ]; then record PASS "$3"
  else record FAIL "$3" "expected [$1], got [$2]"; fi
}

# --- scenario 1: the slices in shape order, a slice with no spec grey ---
same '["idea-board", "gate-card", "pr-gate"]' "$(get '[s["name"] for s in d["slices"]]')" \
  "scenario 1: the 3 slices in shape order"
same "0 A PR gate card. docs/specs/pr-gate.md" "$(get '"%s %s %s" % (S["pr-gate"]["stage"], S["pr-gate"]["text"], S["pr-gate"]["missing"])')" \
  "scenario 1: the slice with no spec is not started, with its What ships text and the path it has no spec at"
same "Living board · Shaped · /review idea-board" "$(get '"%s · %s · %s" % (d["title"], d["status"], d["updated"]["by"])')" \
  "scenario 1: the header data and who updated it"

# --- scenario 2: a slice at pause 1, its spec and its link ---
same "1 docs/specs/gate-card.md" "$(get '"%s %s" % (S["gate-card"]["stage"], S["gate-card"]["spec"])')" \
  "scenario 2: gate-card is at pause 1 and links to its spec"
same '["idea-board"]' "$(get 'S["gate-card"]["needs"]')" "scenario 2: gate-card needs idea-board"
same '[["Flow", "At the end of each stage, the stage builds the board."], ["States", "One slice moves through these stages."]]' \
  "$(get '[[g["caption"], g["say"]] for g in S["idea-board"]["diagrams"]]')" \
  "scenario 2: idea-board's 2 diagrams, each with its heading and the sentence under it"

# --- scenario 3: the choices show under their own slice ---
same "7" "$(get 'S["idea-board"]["stage"]')" "scenario 3: idea-board is shipped"
same '[{"id": "D62", "title": "A script renders the idea board; Claude only publishes it", "why": "the board must look the same after every stage.", "rejected": ["Claude writes the HTML at each stage (the page changes from run to run, and no test can check it)", "Claude edits the last page (it drifts from the files)"]}]' \
  "$(get 'S["idea-board"]["decisions"]')" "scenario 3: D62's title, Why and Rejected options under idea-board"
same '["O1", "O2", "O3"]' "$(get '[r["id"] for r in S["idea-board"]["rows"]]')" \
  "scenario 3: the 3 answered rows, and not the Open one"
same "0" "$(get 'sum(len(s["decisions"]) for s in d["slices"] if s["name"] != "idea-board")')" \
  "scenario 3: no other slice shows D62"

# --- scenario 5: the publish failed, so board.py serve serves the page ---
# When another program holds 4751, the CLI's refusal is checked, and the
# same server runs through serve() on a free port for the rest.
pages="$repo/docs/specs/.pages"
if curl -s -o /dev/null --max-time 2 "http://127.0.0.1:4751/"; then
  echo "e2e-board: port 4751 is in use, so the server is checked on a free port" >&2
  python3 "$board" serve "$pages" 2>"$work/taken.err"
  expect_exit 1 "$?" "serve: port 4751 in use exits 1"
  expect_match "4751" "$(cat "$work/taken.err")" "serve: the message names the port"
  port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
  python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import board; sys.exit(board.serve(sys.argv[2], int(sys.argv[3])))' \
    "$scripts/lib" "$pages" "$port" >/dev/null 2>"$work/serve.err" &
else
  port=4751
  python3 "$board" serve "$pages" >/dev/null 2>"$work/serve.err" &
fi
server=$!
trap 'kill "$server" 2>/dev/null' EXIT
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$port/" && break
  sleep 0.25
done

code() { curl -s -o "$work/body" -w '%{http_code}' --max-time 5 "$@"; }

same "200" "$(code "http://127.0.0.1:$port/living-board-board.html")" "serve: the page at 127.0.0.1"
cmp -s "$work/body" "$page"
expect_exit 0 "$?" "serve: the page served is the page rendered"
same "200" "$(code -H "Host: localhost:$port" "http://127.0.0.1:$port/living-board-board.html")" \
  "serve: Host localhost is allowed"
same "400" "$(code -H "Host: evil.example" "http://127.0.0.1:$port/living-board-board.html")" \
  "serve: any other Host gets 400"
same "400" "$(code -H "Host: evil.example:$port" "http://127.0.0.1:$port/living-board-board.html")" \
  "serve: another host on the same port gets 400"
ln -s ../living-board/shape.md "$pages/out.md"
same "404" "$(code "http://127.0.0.1:$port/out.md")" "serve: a link out of the folder is not served"
same "404" "$(code --path-as-is "http://127.0.0.1:$port/../living-board/shape.md")" \
  "serve: a .. path does not leave the folder"

if [ "$port" = 4751 ]; then
  python3 "$board" serve "$pages" 2>"$work/taken.err"
  expect_exit 1 "$?" "serve: a second server on 4751 exits 1"
  expect_match "4751" "$(cat "$work/taken.err")" "serve: the message names the port"
fi

kill "$server" 2>/dev/null
wait "$server" 2>/dev/null
trap - EXIT
curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$port/"
expect_exit 7 "$?" "serve: the server is stopped"
