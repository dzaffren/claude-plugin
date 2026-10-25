# scripts/lib/board.py -- data reads one shape, the specs it names and
# DECISIONS.md into the board's JSON; render puts that JSON into board.html.
# The fixture project is tests/fixtures/board: one slice per stage under
# stages/, and an old shape whose Slice cells need the name rule.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

board="$scripts/lib/board.py"
fixture="$scripts/tests/fixtures/board"
dir=$(mktemp -d -p "$work")

run() {   # run <args...>; sets $out $err $status
  out=$(python3 "$board" "$@" 2>"$dir/err")
  status=$?
  err=$(cat "$dir/err")
}

# pick <python expression> <json>: d is the board, S its slices by name.
pick() {
  python3 -c 'import json, sys
d = json.loads(sys.argv[2])
S = {s["name"]: s for s in d["slices"]}
v = eval(sys.argv[1])
print(v if isinstance(v, str) else json.dumps(v, ensure_ascii=False))' "$1" "$2" 2>/dev/null
}

same() {  # same <expected> <actual> <description>
  if [ "$2" = "$1" ]; then record PASS "$3"
  else record FAIL "$3" "expected [$1], got [$2]"; fi
}

# --- the idea ---
run data "$fixture/docs/specs/stages/shape.md" --by "/spec pause-one pause 1"
expect_exit 0 "$status" "data: a shape with a Slices table exits 0"
stages=$out
same "stages" "$(pick 'd["idea"]' "$stages")" "idea: the shape's folder name"
same "Stage walk" "$(pick 'd["title"]' "$stages")" "title: the shape's H1"
same "Shaped" "$(pick 'd["status"]' "$stages")" "status: from the shape's Status line"
same "CLI/Library" "$(pick 'd["type"]' "$stages")" "type: from the shape's Project type"
same "One slice per stage, so the board test can read each stage rule." \
  "$(pick 'd["problem"]' "$stages")" "problem: the Problem text, whitespace squeezed"
same "/spec pause-one pause 1" "$(pick 'd["updated"]["by"]' "$stages")" "updated: by is the --by text"
same "$(date +%Y-%m-%d)" "$(pick 'd["updated"]["date"]' "$stages")" "updated: date is today"

# --- slices: the first table under Slices, in shape order ---
same '["not-started", "pause-one", "pause-two", "pause-three", "refined", "built", "reviewed", "shipped"]' \
  "$(pick '[s["name"] for s in d["slices"]]' "$stages")" "slices: the Slices table rows, in order; the second table is not read"
same '[1, 2, 3, 4, 5, 6, 7, 8]' "$(pick '[s["n"] for s in d["slices"]]' "$stages")" "slices: numbered in shape order"

# --- stage: one case per rule ---
i=0
for name in not-started pause-one pause-two pause-three refined built reviewed shipped; do
  same "$i" "$(pick "S['$name']['stage']" "$stages")" "stage: $name is stage $i"
  i=$((i + 1))
done

# --- a slice with no spec ---
same "null" "$(pick 'S["not-started"]["spec"]' "$stages")" "no spec: spec is null"
same "docs/specs/not-started.md" "$(pick 'S["not-started"]["missing"]' "$stages")" "no spec: missing names the path looked for"
same "Ships the first thing." "$(pick 'S["not-started"]["text"]' "$stages")" "no spec: text is the shape's What ships"
same '[[], [], [], []]' "$(pick '[S["not-started"][k] for k in ("needs", "diagrams", "decisions", "rows")]' "$stages")" \
  "no spec: no needs, diagrams, decisions or rows"

# --- a slice with a spec ---
same "docs/specs/pause-one.md" "$(pick 'S["pause-one"]["spec"]' "$stages")" "spec: the path to the slice's spec"
same "null" "$(pick 'S["pause-one"]["missing"]' "$stages")" "spec: missing is null"
same "Pause one opens with this text, wrapped over two lines." "$(pick 'S["pause-one"]["text"]' "$stages")" \
  "spec: text is the first paragraph after the header lines"

# --- diagrams ---
same '["Flow", "States"]' "$(pick '[g["caption"] for g in S["pause-one"]["diagrams"]]' "$stages")" \
  "diagrams: Flow and States, each captioned by the heading above; the fences in a 4-backtick block and in Open items are not copied"
same '["The flow moves from A to B.", "One state only."]' "$(pick '[g["say"] for g in S["pause-one"]["diagrams"]]' "$stages")" \
  "diagrams: the sentence under each fence"
same 'flowchart LR
  A -- reads --> B' "$(pick 'S["pause-one"]["diagrams"][0]["src"]' "$stages")" "diagrams: the source copied as it is"

# --- needs ---
same '["pause-two", "reviewed"]' "$(pick 'S["shipped"]["needs"]' "$stages")" \
  "needs: Depends on names that are slices, in shape order; a name after the dash is not one"
same '["pause-one"]' "$(pick 'S["pause-two"]["needs"]' "$stages")" "needs: a backticked name before the dash"
same '[]' "$(pick 'S["pause-one"]["needs"]' "$stages")" "needs: None is no needs"

# --- decisions ---
same '["D3", "D1"]' "$(pick '[x["id"] for x in S["shipped"]["decisions"]]' "$stages")" \
  "decisions: the entries whose Source is the slice's spec, newest first"
same '["D2"]' "$(pick '[x["id"] for x in S["reviewed"]["decisions"]]' "$stages")" "decisions: another slice gets its own entry"
same '1' "$(pick 'sum(1 for s in d["slices"] if any(x["id"] == "D1" for x in s["decisions"]))' "$stages")" \
  "decisions: D1 shows under its own slice only"
same "Shipped reads one file" "$(pick 'S["shipped"]["decisions"][1]["title"]' "$stages")" "decisions: the heading's title"
same "one file is enough." "$(pick 'S["shipped"]["decisions"][1]["why"]' "$stages")" "decisions: the Why line"
same '["two files (twice the reads, and one, two or three can drift)", "a database (no server)"]' \
  "$(pick 'S["shipped"]["decisions"][1]["rejected"]' "$stages")" \
  "decisions: Rejected split on commas outside parentheses, wrapped lines joined"

# --- rows ---
same '["O1 Resolved", "O3 Accepted risk", "O4 Decided alone"]' \
  "$(pick '[r["id"] + " " + r["status"] for r in S["shipped"]["rows"]]' "$stages")" \
  "rows: Resolved, Accepted risk and Decided alone only; Open and Handed to are left out"
same "Yes, with a | pipe, 2026-10-20" "$(pick 'S["shipped"]["rows"][0]["answer"]' "$stages")" \
  "rows: the answer, with an escaped pipe shown as a pipe"

# --- an old shape's Slice cells ---
run data "$fixture/docs/specs/old/shape.md" --by "/spec release"
expect_exit 0 "$status" "old shape: exits 0"
old=$out
same '["release", "owasp-lens", "decision-log"]' "$(pick '[s["name"] for s in d["slices"]]' "$old")" \
  "old shape: backticks and a leading / removed, lower case, spaces as -"
same '[7, 7, 0]' "$(pick '[s["stage"] for s in d["slices"]]' "$old")" "old shape: the renamed slices find their specs"
same '["release"]' "$(pick 'S["owasp-lens"]["needs"]' "$old")" "old shape: needs uses the same names"
same "docs/specs/decision-log.md" "$(pick 'S["decision-log"]["missing"]' "$old")" "old shape: a cell with no spec names the path"
same "A log the specs never got" "$(pick 'S["decision-log"]["text"]' "$old")" "old shape: What ships found by its header"
same "CLI/Library Shaped" "$(pick 'd["type"] + " " + d["status"]' "$old")" "old shape: a third part on the status line is ignored"

# --- no DECISIONS.md means no entries ---
mkdir -p "$dir/bare/docs/specs/bare"
cp "$fixture/docs/specs/stages/shape.md" "$dir/bare/docs/specs/bare/shape.md"
cp "$fixture/docs/specs/shipped.md" "$dir/bare/docs/specs/"
run data "$dir/bare/docs/specs/bare/shape.md" --by x
expect_exit 0 "$status" "no DECISIONS.md: exits 0"
same '[]' "$(pick 'S["shipped"]["decisions"]' "$out")" "no DECISIONS.md: no decisions"

# --- refusals ---
printf '# Nothing\n\n**Project type:** CLI/Library · **Status:** Draft\n\n## Problem\n\nText.\n' >"$dir/none.md"
run render "$dir/none.md" --by x
expect_exit 2 "$status" "refuse: a shape with no Slices section exits 2"
expect_match "Slices" "$err" "refuse: the message names the Slices table"
same "" "$out" "refuse: nothing on stdout"

printf '# Fenced\n\n## Slices\n\n```\n| # | Slice | What ships |\n| --- | --- | --- |\n| 1 | a | b |\n```\n' >"$dir/fenced.md"
run data "$dir/fenced.md" --by x
expect_exit 2 "$status" "refuse: a Slices table inside a code fence is no table"
expect_match "Slices" "$err" "refuse: the fenced table's message names the Slices table"

run data "$dir/absent.md" --by x
expect_exit 2 "$status" "refuse: a shape that cannot be read exits 2"
expect_match "absent.md" "$err" "refuse: the message names the file"

run data "$fixture/docs/specs/stages/shape.md"
expect_exit 2 "$status" "usage: no --by exits 2"
expect_match "^Usage" "$err" "usage: prints the usage"
run draw "$fixture/docs/specs/stages/shape.md" --by x
expect_exit 2 "$status" "usage: an unknown command exits 2"
expect_match "^Usage" "$err" "usage: an unknown command prints the usage"

# --- render: the page carries the same JSON ---
run render "$fixture/docs/specs/stages/shape.md" --by "/spec pause-one pause 1"
expect_exit 0 "$status" "render: exits 0"
page=$out
printf '%s' "$page" >"$dir/page.html"
slot=$(python3 -c 'import json, sys
page = open(sys.argv[1], encoding="utf-8").read()
start = page.index(">", page.index("<script id=\"data\"")) + 1
d = json.loads(page[start:page.index("</script>", start)])
d["updated"]["date"] = "-"
print(json.dumps(d, sort_keys=True))' "$dir/page.html")
want=$(python3 -c 'import json, sys
d = json.loads(sys.argv[1])
d["updated"]["date"] = "-"
print(json.dumps(d, sort_keys=True))' "$stages")
same "$want" "$slot" "render: the data block parses to what data prints"
expect_no_match "/\*DATA\*/" "$page" "render: the slot is filled"
expect_match "<title>Idea board</title>" "$page" "render: the static title"
expect_match "cdnjs.cloudflare.com/ajax/libs/mermaid/11.12.0/mermaid.min.js" "$page" "render: Mermaid 11.12.0 from cdnjs"
expect_match 'securityLevel: "strict"' "$page" "render: Mermaid runs in strict mode"

# --- render: file text cannot close a script block ---
mkdir -p "$dir/esc/docs/specs/esc"
cat >"$dir/esc/docs/specs/esc/shape.md" <<'SHAPE'
# Escape test

**Project type:** CLI/Library · **Status:** Shaped

## Problem

A </script> in the problem.

## Slices

| # | Slice | What ships | Why |
| --- | --- | --- | --- |
| 1 | evil | </script><script>alert(1)</script> | x |
| 2 | other | <!--<script> | y |
SHAPE
cat >"$dir/esc/docs/specs/evil.md" <<'SPEC'
# Evil

**Version:** v1 · **Status:** Draft · **Type:** Feature · **Project type:** CLI/Library

**Depends on:** None

Opening </script><script>alert(2)</script> and <!--<script> text.

## Flow

```mermaid
flowchart LR
  A["</script>"] --> B
```

</SCRIPT> under it.
SPEC
run render "$dir/esc/docs/specs/esc/shape.md" --by x
expect_exit 0 "$status" "escape: render exits 0"
printf '%s' "$out" >"$dir/esc.html"
# The template's three openers, and every closing tag, in page order.
counts=$(python3 -c 'import re, sys
page = open(sys.argv[1], encoding="utf-8").read().lower()
tags = re.findall(r"<script id=\"data\"|<script src=|<script>\n|</script", page)
print(" ".join("close" if tag == "</script" else "open" for tag in tags), page.count("<!--"))' "$dir/esc.html")
same "open close open close open close 0" "$counts" "escape: three script blocks, each with exactly one closing tag, and no <!-- left"
text=$(python3 -c 'import json, sys
page = open(sys.argv[1], encoding="utf-8").read()
start = page.index(">", page.index("<script id=\"data\"")) + 1
d = json.loads(page[start:page.index("</script>", start)])
print(d["slices"][0]["text"])' "$dir/esc.html")
same 'Opening </script><script>alert(2)</script> and <!--<script> text.' "$text" "escape: the JSON still reads back the text as written"
