# The pr-gate slice end to end, on the repo's own shipped specs: render a
# board for a fixture idea whose slices are the real gate-card and
# idea-board specs, and check each PR card. The real publish and the PR
# body's Board link are checked by hand at the next /ship
# (docs/specs/pr-gate.md, Test plan).
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

board="$scripts/lib/board.py"
real="$(dirname "$(dirname "$(dirname "$scripts")")")/docs/specs"
repo=$(mktemp -d -p "$work")
specs="$repo/docs/specs"
mkdir -p "$specs/living-board"
cp "$real/gate-card.md" "$real/idea-board.md" "$specs/"

cat >"$specs/living-board/shape.md" <<'SHAPE'
# Living board

**Project type:** CLI/Library · **Status:** Shaped

## Slices

| # | Slice | What ships | Why this order |
| --- | --- | --- | --- |
| 1 | idea-board | One page per idea. | First. |
| 2 | gate-card | A card at each pause. | Second. |
SHAPE

python3 "$board" render "$specs/living-board/shape.md" --by "/ship gate-card" >"$repo/page.html" 2>"$repo/err"
expect_exit 0 "$?" "e2e: render exits 0"

# The data block of the rendered page, as /ship publishes it.
get() {
  python3 -c 'import json, re, sys
page = open(sys.argv[2], encoding="utf-8").read()
d = json.loads(re.search(r"<script id=\"data\" type=\"application/json\">(.*?)</script>", page, re.S).group(1))
S = {s["name"]: s["proof"] for s in d["slices"]}
v = eval(sys.argv[1])
print(v if isinstance(v, str) else json.dumps(v, ensure_ascii=False))' "$1" "$repo/page.html" 2>/dev/null
}

same() {  # same <expected> <actual> <description>
  if [ "$2" = "$1" ]; then record PASS "$3"
  else record FAIL "$3" "expected [$1], got [$2]"; fi
}

# --- scenario 1 on gate-card: one row per scenario, each with its test and files ---
same "5" "$(get 'len(S["gate-card"]["rows"])')" "e2e: gate-card's card has its 5 scenarios"
same "a later pause shows what changed since the last stop" "$(get 'S["gate-card"]["rows"][1]["name"]')" \
  "e2e: row 2 is gate-card's second scenario"
same "true" "$(get 'all(r["tests"] and r["tests"][0]["test"].startswith("test-gate.sh") for r in S["gate-card"]["rows"])')" \
  "e2e: each gate-card scenario lists test-gate.sh"
same "true" "$(get '"plugins/zuko/scripts/lib/board.py" in S["gate-card"]["rows"][1]["files"]')" \
  "e2e: scenario 2 lists board.py, once, with no line number"
same "true" "$(get 'all(":" not in f for r in S["gate-card"]["rows"] for f in r["files"])')" \
  "e2e: no file keeps a line number"
same "8" "$(get 'len(S["gate-card"]["alone"])')" "e2e: gate-card's 8 Decided alone rows show"
same "true" "$(get 'all(a["chose"] and a["undo"] for a in S["gate-card"]["alone"])')" \
  "e2e: each Decided alone row has its Chose and Undo"

# --- a second shipped spec, written before the card existed ---
same "5" "$(get 'len(S["idea-board"]["rows"])')" "e2e: idea-board's card has its 5 scenarios"
same "true" "$(get 'all(r["tests"] for r in S["idea-board"]["rows"])')" \
  "e2e: each idea-board scenario has a numbered Test plan row"
