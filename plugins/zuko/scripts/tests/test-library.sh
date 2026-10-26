# scripts/lib/board.py library -- the hub's Ideas section. The e2e walk is
# test-e2e-library.sh; this file has the edge cases, the hub step's prompt
# text in visual-page.md and /shape, and the v3 shape of this repo.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

board="$scripts/lib/board.py"
zuko=$(dirname "$scripts")
here_repo=$(cd "$zuko/../.." && pwd)
dir=$(mktemp -d -p "$work")

run() {   # run <args...>; sets $out $err $status
  out=$(python3 "$board" "$@" 2>"$dir/err")
  status=$?
  err=$(cat "$dir/err")
}

section() { [ -f "$1" ] && awk -v h="## $2" '$0==h{f=1;next} /^## /{f=0} f' "$1" | tr '\n' ' ' | tr -s ' ' || echo "(missing: $1)"; }

# --- usage ---
run library "$dir/nowhere"
expect_exit 2 "$status" "library: a root that is not a directory exits 2"
expect_match 'is not a directory' "$err" "library: says the root is not a directory"

# --- no shapes: no section, no empty heading ---
empty=$(mktemp -d -p "$work")
mkdir -p "$empty/docs/specs"
printf '# loose\n\n**Status:** Shipped\n' >"$empty/docs/specs/loose.md"
run library "$empty"
expect_exit 0 "$status" "library: no shapes exits 0"
expect_exit "" "$out" "library: no shapes prints nothing"
run library "$dir"
expect_exit "" "$out" "library: no docs/specs prints nothing"

# --- a shape that cannot be read (scenario 3) ---
bad=$(mktemp -d -p "$work")
mkdir -p "$bad/docs/specs/csv-import" "$bad/docs/specs/zeta"
printf '\xff\xfe not text\n' >"$bad/docs/specs/csv-import/shape.md"
cat >"$bad/docs/specs/zeta/shape.md" <<'SHAPE'
# <script>alert(1)</script>

**Board:** javascript:alert(1)

## Slices

| # | Slice | What ships |
| --- | --- | --- |
| 1 | a&b | One. |
SHAPE
run library "$bad"
expect_exit 0 "$status" "library: an unreadable shape still exits 0"
expect_match 'data-idea="csv-import".*not read</span> cannot read <code>docs/specs/csv-import/shape.md</code>: ' "$out" \
  "scenario 3: an unreadable shape gives its reason, with the repo path"
expect_no_match "$bad" "$out" "library: the reason names no absolute path"

# --- text is escaped, and only an https Board URL is a link ---
expect_no_match '<script>' "$out" "library: a title cannot add a script"
expect_match '&lt;script&gt;alert\(1\)&lt;/script&gt;' "$out" "library: the title is escaped"
expect_no_match 'href="javascript' "$out" "library: a javascript: Board URL is not a link"
expect_match 'data-idea="zeta".*no board yet' "$out" "library: a Board URL that is not https gives no board yet"
expect_match 'title="a&amp;b · Not started"' "$out" "library: a slice name is escaped"

# --- scenario 4: the hub step in visual-page.md and /shape ---
hub=$(section "$zuko/references/visual-page.md" "Hub page")
expect_match '`/shape`' "$hub" "scenario 4: visual-page.md says /shape builds the hub"
expect_match '4\. \*\*Ideas\.\*\*' "$hub" "scenario 4: the hub's item 4 is Ideas"
expect_match 'board\.py" library \.' "$hub" "scenario 4: the hub step runs board.py library"
expect_match 'Paste its output as it is\. Do not edit it\.' "$hub" "scenario 4: the fragment is pasted, not edited"
expect_match 'No output means no Ideas section\.' "$hub" "scenario 4: no output, no section"
expect_match '5\. \*\*Slices\.\*\*.*6\. \*\*Links\.\*\*' "$hub" "scenario 4: Slices and Links follow Ideas"
shape=$(tr '\n' ' ' <"$zuko/skills/shape/SKILL.md" | tr -s ' ')
expect_match 'Then publish the hub page, as `\$\{CLAUDE_PLUGIN_ROOT\}/references/visual-page\.md` › "Hub page" says\.' "$shape" \
  "scenario 4: /shape publishes the hub after the board"
expect_match 'no `hub page:` link on the overview.s `## More` line.*add the `hub page: \{url\}`' "$shape" \
  "scenario 4: /shape creates the hub and writes its link when there is none"

# --- scenario 5: this repo's v3 release idea counts every spec ---
run library "$here_repo"
v3=$(grep -F 'data-idea="v3-release-and-hosts"' <<<"$out")
expect_match '14 of 14 shipped' "$v3" "scenario 5: v3-release-and-hosts says 14 of 14 shipped"
expect_no_match 'class="none"' "$v3" "scenario 5: no v3 slice is Not started"
