# scripts/render-readme-block.sh -- the README block rendered from OVERVIEW.md.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

work=$(mktemp -d)

# The invoice-cli overview: three commands and a lint that is not set up, one
# Built slice and one Shipped. <export-status> sets the export-csv row.
write_overview() {   # write_overview <dir> [export-status]
  cat >"$1/OVERVIEW.md" <<OVERVIEW
# invoice-cli

**Status:** Active · **Updated:** 2026-09-24 by /ship ledger-merge

Turns a folder of supplier invoices into one ledger CSV. Used by the finance team
at month end; about 400 invoices a run.

## Run it

| Task    | Command                     |
| ------- | --------------------------- |
| install | \`pip install -e .\`          |
| run     | \`invoice-cli build ./inbox\` |
| test    | \`pytest\`                    |
| lint    | not set up yet              |

## Where things are

- \`src/\` — the CLI

## Slices

| Slice        | Status          | What it does                  | Page                  |
| ------------ | --------------- | ----------------------------- | --------------------- |
| ledger-merge | Shipped         | Merge invoices into a ledger  | https://claude.ai/... |
| export-csv   | ${2:-Built}     | Export the ledger as one CSV  | https://claude.ai/... |

## More

README.md · docs/ARCHITECTURE.md
OVERVIEW
}

render() {      # render <dir> [flag]; sets $out (stdout+stderr) $status
  out=$(cd "$1" && CLAUDE_PROJECT_DIR="$1" bash "$scripts/render-readme-block.sh" ${2:+"$2"} 2>&1)
  status=$?
}

# 1. Print: every section, in order, from the invoice-cli overview.
dir=$(mktemp -d -p "$work"); write_overview "$dir"; render "$dir"
expect_exit 0 "$status" "print: exits 0"
expect_match '^<!-- zuko:start — generated from OVERVIEW\.md; edit that file, not this block -->$' \
  "$(printf '%s\n' "$out" | head -1)" "print: opens with the default start marker"
expect_match '^<!-- zuko:end -->$' "$(printf '%s\n' "$out" | tail -1)" "print: closes with the end marker"
headings=$(printf '%s\n' "$out" | grep '^#' | tr '\n' '/')
expect_match '^## What it does/## Install and run/## Features/## Docs/$' "$headings" "print: four ## sections, in order"
expect_match '^Turns a folder of supplier invoices into one ledger CSV\. Used by the finance team$' "$out" "print: the description, copied as is"
expect_match '^at month end; about 400 invoices a run\.$' "$out" "print: every line of the description"
expect_no_match 'Status:|Updated:' "$out" "print: the Status line is not part of the description"
expect_match '^\| install \| `pip install -e \.`          \|$' "$out" "print: the install row, padded to the column"
expect_match '^\| test    \| `pytest`                    \|$' "$out" "print: the test row"
expect_match '^\| ------- \| --------------------------- \|$' "$out" "print: the separator is padded too"
expect_no_match 'lint|not set up yet' "$out" "print: a not-set-up command is dropped"
expect_match '^- Merge invoices into a ledger$' "$out" "print: a Shipped row is a feature"
expect_no_match 'Export the ledger' "$out" "print: a Built row is not"
expect_match '^- \[Overview\]\(OVERVIEW\.md\)$' "$out" "print: docs link the overview"
expect_no_match 'ARCHITECTURE|DECISIONS|CHANGELOG' "$out" "print: docs skip files that do not exist"
expect_no_match 'https?:' "$out" "print: no URL leaves the repo"

# 2. Features in table order; docs that exist are listed in the fixed order.
dir=$(mktemp -d -p "$work"); write_overview "$dir" Shipped
mkdir -p "$dir/docs"; touch "$dir/docs/ARCHITECTURE.md" "$dir/CHANGELOG.md" "$dir/DECISIONS.md"
render "$dir"
features=$(printf '%s\n' "$out" | grep '^- [A-Z]' | tr '\n' '/')
expect_match '^- Merge invoices into a ledger/- Export the ledger as one CSV/$' "$features" "features: every Shipped row, in table order"
docs=$(printf '%s\n' "$out" | grep '^- \[' | tr '\n' '/')
expect_match '^- \[Overview\]\(OVERVIEW\.md\)/- \[Architecture\]\(docs/ARCHITECTURE\.md\)/- \[Decisions\]\(DECISIONS\.md\)/- \[Changelog\]\(CHANGELOG\.md\)/$' \
  "$docs" "docs: every file that exists, in the fixed order"

# The habit-tracker overview, as onboarding writes it on a greenfield repo.
write_greenfield_overview() {   # write_greenfield_overview <dir>
  cat >"$1/OVERVIEW.md" <<'OVERVIEW'
# habit-tracker

**Status:** Active · **Updated:** 2026-09-24 by /spec onboarding

Tracks daily habits and shows streaks. Used by one person, on their phone.

## Run it

| Task    | Command        |
| ------- | -------------- |
| install | not set up yet |
| run     | not set up yet |
| test    | not set up yet |
| lint    | not set up yet |

## Slices

Nothing shipped yet

| Slice    | Status   | What it does | Page     |
| -------- | -------- | ------------ | -------- |
| none yet | none yet | none yet     | none yet |

## More

README.md
OVERVIEW
}

# 3. Scenario 3: a greenfield README is the title and the block.
dir=$(mktemp -d -p "$work"); write_greenfield_overview "$dir"
printf '# habit-tracker\n\n%s\n%s\n' \
  '<!-- zuko:start — generated from OVERVIEW.md; edit that file, not this block -->' \
  '<!-- zuko:end -->' >"$dir/README.md"
render "$dir" --write
expect_exit 0 "$status" "greenfield --write: exits 0"
expect_match '^README\.md  zuko block rewritten$' "$out" "greenfield --write: says rewritten"
readme=$(cat "$dir/README.md")
expect_match '^# habit-tracker$' "$(printf '%s\n' "$readme" | head -1)" "greenfield: the title comes first"
expect_match '^<!-- zuko:start — generated from OVERVIEW\.md' "$(printf '%s\n' "$readme" | sed -n 3p)" "greenfield: the block follows the title"
expect_match '^<!-- zuko:end -->$' "$(printf '%s\n' "$readme" | tail -1)" "greenfield: the block ends the file"
expect_match '^Tracks daily habits and shows streaks\.' "$readme" "greenfield: the description is rendered"
features=$(printf '%s\n' "$readme" | sed -n '/^## Features$/,/^## Docs$/p')
expect_match '^Nothing shipped yet$' "$features" "greenfield: Features says Nothing shipped yet"
expect_no_match 'none yet' "$readme" "greenfield: the none-yet row is not a feature"
expect_no_match 'Install and run|not set up yet' "$readme" "greenfield: no command set up, no Install and run section"
render "$dir" --check
expect_exit 0 "$status" "greenfield --check after --write: exits 0"
expect_match '^README\.md  zuko block up to date$' "$out" "greenfield --check after --write: up to date"

# 3b. No README.md at all: onboarding adds it; the renderer never creates one.
dir=$(mktemp -d -p "$work"); write_greenfield_overview "$dir"
render "$dir" --write
expect_exit 1 "$status" "no README --write: exits 1"
expect_match '^README\.md  no zuko block — onboarding adds it$' "$out" "no README --write: says onboarding adds it"
[ -e "$dir/README.md" ] && created=yes || created=no
expect_match '^no$' "$created" "no README --write: no README is created"
render "$dir" --check
expect_exit 1 "$status" "no README --check: exits 1"
expect_match '^README\.md  no zuko block — onboarding adds it$' "$out" "no README --check: says onboarding adds it"

# 3c. A README with no markers: the same, and the file is left alone.
dir=$(mktemp -d -p "$work"); write_greenfield_overview "$dir"
printf '# habit-tracker\n\nNotes.\n' >"$dir/README.md"; cp "$dir/README.md" "$dir/before"
render "$dir" --write
expect_exit 1 "$status" "no markers --write: exits 1"
expect_match '^README\.md  no zuko block — onboarding adds it$' "$out" "no markers --write: says onboarding adds it"
cmp -s "$dir/before" "$dir/README.md" && same=yes || same=no
expect_match '^yes$' "$same" "no markers --write: README.md untouched"

rm -rf "$work"
