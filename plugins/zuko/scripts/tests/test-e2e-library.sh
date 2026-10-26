# One walk through the library slice: a fixture repo with three shapes
# (living-board with a Board line, ask-up-front without one, billing-export
# with no Slices table), a spec with no shape and an OVERVIEW.md.
# board.py library prints the Ideas section; the stage pastes it into the hub
# between Architecture and Slices, and scenarios 1 to 3 are read from that hub.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

board="$scripts/lib/board.py"
repo=$(mktemp -d -p "$work")
mkdir -p "$repo/docs/specs/living-board" "$repo/docs/specs/ask-up-front" \
  "$repo/docs/specs/billing-export" "$repo/docs/specs/.pages"

cat >"$repo/OVERVIEW.md" <<'OVERVIEW'
# invoice-cli

**Status:** Active

## More

README.md · hub page: https://claude.ai/artifact/HubHubHubHub
OVERVIEW

cat >"$repo/docs/specs/living-board/shape.md" <<'SHAPE'
# Living board

**Project type:** CLI/Library · **Status:** Shaped
**Board:** https://claude.ai/artifact/6ZvDtf657jw6ohs94cyYvs

## Slices

| # | Slice | What ships | Why this order |
| --- | --- | --- | --- |
| 1 | idea-board | One page per idea. | First. |
| 2 | gate-card | A gate card. | Needs the page. |
| 3 | pr-gate | A PR card. | Needs the page. |
| 4 | library | The hub lists the ideas. | Needs two boards. |
| 5 | replay | A replay. | Last. |
SHAPE

cat >"$repo/docs/specs/ask-up-front/shape.md" <<'SHAPE'
# Ask up front, decide at the PR

**Project type:** CLI/Library · **Status:** Shaped

## Slices

| # | Slice | What ships | Why this order |
| --- | --- | --- | --- |
| 1 | stop-hook-scope | Stop hooks judge only changed docs. | First. |
| 2 | decision-pr | The PR body starts with the choices. | Last. |
SHAPE

cat >"$repo/docs/specs/billing-export/shape.md" <<'SHAPE'
# Billing export

**Project type:** CLI/Library · **Status:** Draft

## Problem

Finance exports invoices by hand.
SHAPE

for name in idea-board gate-card pr-gate stop-hook-scope decision-pr tokenise-linear; do
  printf '# %s\n\n**Version:** v1 · **Status:** Shipped · **Type:** Feature\n' "$name" >"$repo/docs/specs/$name.md"
done

fragment=$(cd "$repo" && python3 "$board" library . 2>"$repo/err")
expect_exit 0 "$?" "e2e library: board.py library exits 0 with a shape it cannot read"

hub="$repo/docs/specs/.pages/_hub.html"
{
  printf '<!doctype html><title>invoice-cli</title><main>\n<section><h2>Architecture</h2></section>\n'
  printf '%s\n' "$fragment"
  printf '<section><h2>Slices</h2><table><tr><td>tokenise-linear</td></tr></table></section>\n</main>\n'
} >"$hub"

# rows, one line each, in page order
rows=$(python3 - "$hub" <<'PY'
import re, sys
page = open(sys.argv[1], encoding="utf-8").read()
for row in re.findall(r'<tr class="idea"[^>]*>.*?</tr>', page, re.S):
    print(" ".join(row.split()))
PY
)
row() { grep -F "data-idea=\"$1\"" <<<"$rows"; }

expect_match '^<section class="zuko-ideas"' "$fragment" "e2e library: the fragment is one Ideas section"
expect_match '<h2 id="zuko-ideas">Ideas</h2>' "$fragment" "e2e library: the section has the Ideas heading"

# --- scenario 1: an idea with a board ---
living=$(row living-board)
expect_match '<b>Living board</b>' "$living" "scenario 1: the row has the shape's title"
expect_match '<a href="https://claude.ai/artifact/6ZvDtf657jw6ohs94cyYvs">open board</a>' "$living" "scenario 1: the row links to the board"
expect_match '3 of 5 shipped' "$living" "scenario 1: the row says 3 of 5 shipped"
expect_exit 3 "$(grep -o '<li class="ship"' <<<"$living" | wc -l | tr -d ' ')" "scenario 1: three Shipped marks"
expect_exit 2 "$(grep -o '<li class="none"' <<<"$living" | wc -l | tr -d ' ')" "scenario 1: two Not started marks"
expect_match 'title="library · Not started"' "$living" "scenario 1: a mark is titled with its slice and stage"
expect_no_match 'tokenise-linear' "$fragment" "scenario 1: the spec with no shape is not in the Ideas section"

# --- scenario 2: an idea with no board ---
ask=$(row ask-up-front)
expect_match '<b>Ask up front, decide at the PR</b>' "$ask" "scenario 2: the row has the shape's title"
expect_match 'no board yet · <code>docs/specs/ask-up-front/shape.md</code>' "$ask" "scenario 2: no board yet, with the shape path"
expect_match '2 of 2 shipped' "$ask" "scenario 2: the row says 2 of 2 shipped"
expect_no_match '<a ' "$ask" "scenario 2: the row has no link"

# --- scenario 3: a shape with no Slices table ---
broken=$(row billing-export)
expect_match 'not read</span> no Slices table in <code>docs/specs/billing-export/shape.md</code>' "$broken" \
  "scenario 3: the error row gives the reason"
expect_match '<td colspan="2">' "$broken" "scenario 3: the reason spans Progress and Board"

# --- row order: error rows, in flight, finished ---
order=$(sed -n 's/.*data-idea="\([^"]*\)".*/\1/p' <<<"$rows" | tr '\n' ' ')
expect_exit "billing-export living-board ask-up-front " "$order" "e2e library: error rows first, then in flight, then finished"
