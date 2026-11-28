# scripts/lib/words.py, check-words.sh and verify-gates.sh -- the lines that
# this work added to a shape or spec use no zuko label alone, no listed
# metaphor or hard word, and no D or O number before its plain words.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

# git reads this machine's global config from HOME; the scratch repos get an empty one.
export HOME="$work/words-home" XDG_CONFIG_HOME="$work/words-home/.config" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME"

g() { git -C "$repo" -c user.name=Zuko -c user.email=zuko@example.com -c commit.gpgsign=false "$@"; }

new_repo() {   # a git repo on main with one commit, then a work branch; path in $repo
  repo=$(mktemp -d -p "$work")
  git init -q -b main "$repo"
  mkdir -p "$repo/docs/specs"
  echo "# Raslaw" >"$repo/README.md"
  g add -A
  g commit -q -m "chore: start"
  g checkout -q -b feat/refund-export
}

spec() {       # spec <file under docs/specs> <body>: a zuko spec with <body> under ## Problem
  mkdir -p "$(dirname "$repo/docs/specs/$1")"
  cat >"$repo/docs/specs/$1" <<SPEC
# refund-export

**Version:** v1 · **Status:** Draft · **Type:** Feature · **Project type:** CLI/Library

## Problem

$2

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
SPEC
}

words() {      # words <file under docs/specs>: sets $words_out $words_status
  words_out=$(python3 "$scripts/lib/words.py" check "$repo" "$repo/docs/specs/$1" 2>&1)
  words_status=$?
}

# The line number of the first line holding <text> in <file under docs/specs>.
line_of() { grep -nF -- "$2" "$repo/docs/specs/$1" | head -1 | cut -d: -f1; }

new_repo

# --- Scenario 1: a zuko label used alone ---

spec refund-export.md "The ledger has no Open rows."
words refund-export.md
n=$(line_of refund-export.md "The ledger has")
expect_exit 0 "$words_status" "label: words.py exits 0 when it printed findings"
expect_match "^$(native "$repo")/docs/specs/refund-export\.md	$n	\"ledger\" is a zuko label used alone\. Write \"the open-items table \(ledger\)\"\.$" \
  "$words_out" "label: names the line and gives the plain words"

spec refund-export.md "The open-items table (ledger) has no Open rows."
words refund-export.md
expect_match '^$' "$words_out" "label: in brackets after plain words, no finding"

spec refund-export.md "Ledgers grow, and references/ledger.md and ledger-handoff.md are paths."
words refund-export.md
expect_match '"Ledgers" is a zuko label used alone' "$words_out" "label: a plural in any case counts"
expect_no_match 'ledger\.md|ledger-handoff' "$words_out" "label: a path or file name does not count"

# --- Scenario 2: a metaphor or a hard word gets its swap ---

spec refund-export.md "Each stage will surface the goal prior to the questions."
words refund-export.md
expect_match '"surface the" is a metaphor\. Write "show"\.$' "$words_out" "swap: a metaphor gets its literal word"
expect_match '"prior to" is a hard word\. Write "before"\.$' "$words_out" "swap: a hard word gets its plain swap"

spec refund-export.md "Each stage will show the goal (surface it) first."
words refund-export.md
expect_match '"surface it" is a metaphor' "$words_out" "swap: brackets do not excuse a metaphor"

spec refund-export.md "The command surface and the security surface stay small."
words refund-export.md
expect_match '^$' "$words_out" "swap: surface as a noun is not the metaphor"

# --- The spec template's fixed text passes ---

sed 's/{Feature | Bug | Enhancement | Technical | Skeleton}/Feature/' \
  "$scripts/../skills/spec/references/spec-template.md" >"$repo/docs/specs/template-copy.md"
words template-copy.md
expect_exit 0 "$words_status" "template: words.py runs on a copy"
expect_match '^$' "$words_out" "template: the fixed text has no finding"
rm "$repo/docs/specs/template-copy.md"

# --- Scenario 3: a number comes only after its plain words ---

spec refund-export.md "D38 says that nothing measures sentence length, and O7 agrees."
words refund-export.md
expect_match '"D38" comes before its plain words\. Write the plain words, then "\(D38\)"\.$' "$words_out" \
  "number: a D-number before its plain words"
expect_match '"O7" comes before its plain words' "$words_out" "number: an O-number before its plain words"

spec refund-export.md "Nothing measures sentence length (D38). The board rules go (D62 to D74, O1 and O2)."
words refund-export.md
expect_match '^$' "$words_out" "number: in brackets, alone or in a range, no finding"

# --- Scenario 4: sentence cells, not the columns that scripts read ---

spec refund-export.md "The export is a CSV."
echo '| O24 | Can the hook reply? | unproven | shape | user | Handed to plain-words | The ledger says yes. |' \
  >>"$repo/docs/specs/refund-export.md"
words refund-export.md
n=$(line_of refund-export.md "| O24 |")
expect_match "	$n	\"ledger\" is a zuko label used alone" "$words_out" "table: the Answer cell is read"
expect_no_match '"O24"' "$words_out" "table: the ID column is skipped"
count=$(grep -c . <<<"$words_out")
expect_exit 1 "$count" "table: one finding, from the Answer cell only"

# --- Scenario 5: old text stays as it is ---

spec refund-export.md "The ledger has no Open rows."
g add -A
g commit -q -m "docs(spec): add refund-export"
g checkout -q main
g merge -q --ff-only feat/refund-export
g checkout -q -b feat/ship-refund-export
sed -i.bak 's/\*\*Status:\*\* Draft/**Status:** Shipped/' "$repo/docs/specs/refund-export.md"
rm -f "$repo/docs/specs/refund-export.md.bak"
words refund-export.md
expect_exit 0 "$words_status" "old text: a Status-only edit runs"
expect_match '^$' "$words_out" "old text: a line from before this branch is not read"

echo "The second ledger is new." >>"$repo/docs/specs/refund-export.md"
words refund-export.md
expect_match '"ledger" is a zuko label used alone' "$words_out" "old text: a line this branch added is read"
expect_no_match "	$(line_of refund-export.md "The ledger has")	" "$words_out" "old text: the old line still is not"

echo "The ledger is empty." >"$repo/README.md"
words_out=$(python3 "$scripts/lib/words.py" check "$repo" "$repo/README.md" 2>&1)
expect_exit 0 "$?" "not a doc: README.md runs"
expect_match '^$' "$words_out" "not a doc: README.md is never checked"

# --- What the check skips ---

new_repo
spec refund-export.md 'The export says "the ledger is empty" when it has no rows.
The check runs `ledger --surface D38`, in a span that wraps `onto
the ledger line` here.

```text
The ledger has no Open rows (D38 aside).
```

### The ledger, in a heading'
cat >>"$repo/docs/specs/refund-export.md" <<'TAIL'

### Decisions to record

#### D9 · 2026-11-28 · The ledger stays

Supersedes: D38
Status: active

## Glossary

- **ledger** — the open-items table.
TAIL
words refund-export.md
expect_exit 0 "$words_status" "skips: words.py runs"
expect_match '^$' "$words_out" "skips: quotes, code, a wrapped span, a fence, headings, drafted entries and the Glossary"

# A lone backtick opens no span past its paragraph, as CommonMark reads it.
spec refund-export.md 'Split each field on the ` character.

The ledger has no Open rows.

Run `make test` after.'
words refund-export.md
expect_match "	$(line_of refund-export.md "The ledger has")	\"ledger\" is a zuko label used alone" "$words_out" \
  "skips: a lone backtick does not hide the next paragraph"

# --- A doc saved through Bash: the Stop hook checks it too ---

spec refund-export.md "The ledger has no Open rows."
gate_out=$(CLAUDE_PROJECT_DIR="$repo" bash "$scripts/verify-gates.sh" <<<'{}' 2>&1)
expect_exit 2 "$?" "stop: the gate fails"
expect_match "^- $(native "$repo")/docs/specs/refund-export\.md line [0-9]+: \"ledger\" is a zuko label used alone\." \
  "$gate_out" "stop: names the doc, the line and the finding"

# --- No base branch: every line counts as added ---

repo=$(mktemp -d -p "$work")
mkdir -p "$repo/docs/specs"
spec refund-export.md "The ledger has no Open rows."
words refund-export.md
expect_match '"ledger" is a zuko label used alone' "$words_out" "no git: every line is read"

# --- The check cannot run: it fails closed ---

fake="$work/fake-zuko"
mkdir -p "$fake/scripts" "$fake/references"
cp -R "$scripts/lib" "$fake/scripts/lib"
printf '# Voice\n\n## Rules\n\n1. Say the thing first.\n' >"$fake/references/voice.md"
words_out=$(python3 "$fake/scripts/lib/words.py" check "$repo" "$repo/docs/specs/refund-export.md" 2>&1)
expect_exit 2 "$?" "no word list: exits 2, never 0"
expect_match 'voice\.md has no ## Word list table\.' "$words_out" "no word list: says why"

words_out=$(python3 "$fake/scripts/lib/words.py" check "$repo" "$repo/README.md" 2>&1)
expect_exit 0 "$?" "no word list: a file that is not a doc still passes"

words_out=$(python3 "$scripts/lib/words.py" 2>&1)
expect_exit 2 "$?" "usage: no arguments exits 2"

# --- The real word list in voice.md ---

new_repo
spec refund-export.md "We utilize the export, and we utilise it in order to merge."
words refund-export.md
expect_match '"utilize" is a hard word\. Write "use"\.$' "$words_out" "voice.md: a cell with two spellings gives the first"
expect_match '"utilise" is a hard word\. Write "use"\.$' "$words_out" "voice.md: and the second"
expect_match '"in order to" is a hard word\. Write "to"\.$' "$words_out" "voice.md: a phrase of three words"
