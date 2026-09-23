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

rm -rf "$work"
