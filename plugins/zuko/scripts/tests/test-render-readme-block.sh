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

# Every byte of <file> outside the block: up to the end of the start marker
# line, and from the end marker on.
outside() {     # outside <file>
  python3 -c '
import sys
data = open(sys.argv[1], "rb").read()
start = data.index(b"\n", data.index(b"<!-- zuko:start")) + 1
sys.stdout.buffer.write(data[:start] + data[data.index(b"<!-- zuko:end -->"):])
' "$1"
}

same_bytes() {  # same_bytes <a> <b>; prints yes or no
  cmp -s "$1" "$2" && echo yes || echo no
}

# invoice-cli's README: text before the block, and a License section after it.
write_invoice_readme() {   # write_invoice_readme <dir>
  cat >"$1/README.md" <<'README'
# invoice-cli

[![ci](badge.svg)](ci.yml)

A small tool.

<!-- zuko:start — generated from OVERVIEW.md; edit that file, not this block -->
<!-- zuko:end -->

## License

MIT. Keep this   spacing.
README
}

# 4. Scenario 4: a slice ships, the block is stale, --write re-renders it.
dir=$(mktemp -d -p "$work"); write_overview "$dir"; write_invoice_readme "$dir"
render "$dir" --write
outside "$dir/README.md" >"$dir/outside.before"
write_overview "$dir" Shipped
render "$dir" --check
expect_exit 1 "$status" "shipped: --check exits 1"
expect_match '^README\.md  zuko block is stale — run render-readme-block\.sh --write$' \
  "$(printf '%s\n' "$out" | head -1)" "shipped: --check says stale first"
expect_match '^\+- Export the ledger as one CSV$' "$out" "shipped: the diff shows the new feature"
render "$dir" --write
expect_exit 0 "$status" "shipped: --write exits 0"
expect_match '^README\.md  zuko block rewritten$' "$out" "shipped: --write says rewritten"
expect_match '^- Export the ledger as one CSV$' "$(cat "$dir/README.md")" "shipped: the feature is in the block"
outside "$dir/README.md" >"$dir/outside.after"
expect_match '^yes$' "$(same_bytes "$dir/outside.before" "$dir/outside.after")" "shipped: every byte outside the markers is unchanged"
expect_match '^## License$' "$(cat "$dir/outside.after")" "shipped: the License section is still there"
render "$dir" --check
expect_exit 0 "$status" "shipped: --check after --write exits 0"
expect_match '^README\.md  zuko block up to date$' "$out" "shipped: --check after --write says up to date"

# 4b. CRLF line endings and no final newline survive a rewrite byte for byte.
dir=$(mktemp -d -p "$work"); write_overview "$dir"
printf '# invoice-cli\r\n\r\n%s\r\nold\r\n%s\r\n\r\n## License\r\nMIT' \
  '<!-- zuko:start — generated from OVERVIEW.md; edit that file, not this block -->' \
  '<!-- zuko:end -->' >"$dir/README.md"
outside "$dir/README.md" >"$dir/outside.before"
render "$dir" --write
expect_exit 0 "$status" "crlf: --write exits 0"
outside "$dir/README.md" >"$dir/outside.after"
expect_match '^yes$' "$(same_bytes "$dir/outside.before" "$dir/outside.after")" "crlf: bytes outside the markers unchanged"
expect_match '^1$' "$(grep -vc $'\r$' "$dir/README.md")" "crlf: every line but the unterminated last one ends CRLF"
render "$dir" --check
expect_exit 0 "$status" "crlf: --check after --write exits 0"

# 4c. A formatter re-pads the block's tables: still up to date.
dir=$(mktemp -d -p "$work"); write_overview "$dir"; write_invoice_readme "$dir"
render "$dir" --write
sed -E '/^\|/{s/ +/ /g; s/^\| -+ \| -+ \|$/|---|---|/; s/^\| install \|/|install|/;}; /^## What it does$/s/$/  /' \
  "$dir/README.md" >"$dir/padded"
cp "$dir/padded" "$dir/README.md"
expect_match '^\|---\|---\|$' "$(cat "$dir/README.md")" "padded: the separator really was reshaped"
render "$dir" --check
expect_exit 0 "$status" "padded: --check still exits 0"
expect_match '^README\.md  zuko block up to date$' "$out" "padded: --check says up to date"

# 4d. A changed word is stale, whatever the padding.
sed 's/`pytest`/`pytest -q`/' "$dir/padded" >"$dir/README.md"
render "$dir" --check
expect_exit 1 "$status" "changed command: --check exits 1"
expect_match 'zuko block is stale' "$out" "changed command: says stale"

# 4e. A hand-edit: stale, and the diff shows both sides.
dir=$(mktemp -d -p "$work"); write_overview "$dir"; write_invoice_readme "$dir"
render "$dir" --write
sed 's/pip install -e \./pip install invoice/' "$dir/README.md" >"$dir/edited"; cp "$dir/edited" "$dir/README.md"
render "$dir" --check
expect_exit 1 "$status" "hand-edit: --check exits 1"
expect_match '^-\| install \| `pip install invoice`' "$out" "hand-edit: the diff shows the README line"
expect_match '^\+\| install \| `pip install -e \.`' "$out" "hand-edit: the diff shows the rendered line"
cmp -s "$dir/edited" "$dir/README.md" && same=yes || same=no
expect_match '^yes$' "$same" "hand-edit: --check writes nothing"

# 4f. The diff is capped at 40 lines.
dir=$(mktemp -d -p "$work"); write_overview "$dir"
{ echo '# invoice-cli'; echo '<!-- zuko:start — generated from OVERVIEW.md; edit that file, not this block -->'
  for i in $(seq 1 80); do echo "junk line $i"; done; echo '<!-- zuko:end -->'; } >"$dir/README.md"
render "$dir" --check
expect_exit 1 "$status" "long diff: --check exits 1"
diff_lines=$(printf '%s\n' "$out" | sed 1d | grep -vc '^\.\.\. ')
[ "$diff_lines" -le 40 ] && capped=yes || capped="no: $diff_lines lines"
expect_match '^yes$' "$capped" "long diff: at most 40 diff lines"
expect_match '^\.\.\. diff cut at 40 lines$' "$out" "long diff: says it was cut"

skip_marker='<!-- zuko:start skip=install — generated from OVERVIEW.md; edit that file, not this block -->'

# invoice-cli's README after a rejected merge: its own Install section stays,
# and the start marker records skip=<keys>.
write_skipping_readme() {   # write_skipping_readme <dir> <keys>
  cat >"$1/README.md" <<README
# invoice-cli

## Install

    pip install -e .

<!-- zuko:start skip=$2 — generated from OVERVIEW.md; edit that file, not this block -->
<!-- zuko:end -->

## License

MIT.
README
}

# 2. Scenario 2: skip=install keeps the user's Install and drops the section.
dir=$(mktemp -d -p "$work"); write_overview "$dir"; write_skipping_readme "$dir" install
outside "$dir/README.md" >"$dir/outside.before"
render "$dir"
expect_exit 0 "$status" "skip=install print: exits 0"
expect_match "^$skip_marker\$" "$(printf '%s\n' "$out" | head -1)" "skip=install print: uses README's start marker"
expect_no_match '^## Install and run$|pip install' "$out" "skip=install print: no Install and run section"
expect_match '^## Features$' "$out" "skip=install print: the other sections stay"
render "$dir" --write
expect_exit 0 "$status" "skip=install --write: exits 0"
readme=$(cat "$dir/README.md")
expect_match "^$skip_marker\$" "$readme" "skip=install --write: the marker, skip list and all, survives"
expect_no_match '^## Install and run$' "$readme" "skip=install --write: no Install and run section"
expect_match '^## What it does$' "$readme" "skip=install --write: the block was rendered"
outside "$dir/README.md" >"$dir/outside.after"
expect_match '^yes$' "$(same_bytes "$dir/outside.before" "$dir/outside.after")" "skip=install --write: ## Install and everything outside unchanged"
render "$dir" --check
expect_exit 0 "$status" "skip=install --check: exits 0"
render "$dir" --write
expect_match "^$skip_marker\$" "$(cat "$dir/README.md")" "skip=install: survives a second re-render"

# 2b. Several keys, every one of them honoured.
dir=$(mktemp -d -p "$work"); write_overview "$dir" Shipped; write_skipping_readme "$dir" what,features,docs
render "$dir" --write
expect_exit 0 "$status" "skip=what,features,docs: exits 0"
headings=$(sed -n '/zuko:start/,/zuko:end/p' "$dir/README.md" | grep '^## ' | tr '\n' '/')
expect_match '^## Install and run/$' "$headings" "skip=what,features,docs: only Install and run is left"

# 2c. An unknown key: exit 2, and README.md is not touched.
dir=$(mktemp -d -p "$work"); write_overview "$dir"; write_skipping_readme "$dir" install,licence
cp "$dir/README.md" "$dir/before"
render "$dir" --write
expect_exit 2 "$status" "skip=licence --write: exits 2"
expect_match '^README\.md  unknown skip key "licence"$' "$out" "skip=licence: names the key"
expect_match '^yes$' "$(same_bytes "$dir/before" "$dir/README.md")" "skip=licence --write: README.md byte-identical"
render "$dir" --check
expect_exit 2 "$status" "skip=licence --check: exits 2"
render "$dir"
expect_exit 2 "$status" "skip=licence print: exits 2"

# Every input that cannot render: exit 2 on every mode, its message, and
# --write leaves README.md byte-identical.
cannot_render() {   # cannot_render <dir> <message-regex> <label>
  cp "$1/README.md" "$1/before"
  local mode
  for mode in --write --check ""; do
    render "$1" $mode
    expect_exit 2 "$status" "$3 ${mode:-print}: exits 2"
    expect_match "$2" "$out" "$3 ${mode:-print}: says why"
  done
  expect_match '^yes$' "$(same_bytes "$1/before" "$1/README.md")" "$3: README.md byte-identical"
}

start_line='<!-- zuko:start — generated from OVERVIEW.md; edit that file, not this block -->'

dir=$(mktemp -d -p "$work"); write_invoice_readme "$dir"
cannot_render "$dir" '^OVERVIEW\.md  missing$' "no overview"

dir=$(mktemp -d -p "$work"); write_overview "$dir"; write_invoice_readme "$dir"
sed '/^## Run it$/,/^## Where/{/^|/d;}' "$dir/OVERVIEW.md" >"$dir/o"; mv "$dir/o" "$dir/OVERVIEW.md"
cannot_render "$dir" '^OVERVIEW\.md  no "## Run it" table$' "no Run it table"

# A Run it table inside a fence is an example, not the table.
dir=$(mktemp -d -p "$work"); write_overview "$dir"; write_invoice_readme "$dir"
sed -e '/^| Task/i\
```' -e '/^| lint/a\
```' "$dir/OVERVIEW.md" >"$dir/o"; mv "$dir/o" "$dir/OVERVIEW.md"
expect_match '^```$' "$(cat "$dir/OVERVIEW.md")" "fenced table: the fixture really has a fence"
cannot_render "$dir" '^OVERVIEW\.md  no "## Run it" table$' "fenced Run it table"

dir=$(mktemp -d -p "$work"); write_overview "$dir"; write_invoice_readme "$dir"
sed 's/| What it does /| Summary      /' "$dir/OVERVIEW.md" >"$dir/o"; mv "$dir/o" "$dir/OVERVIEW.md"
cannot_render "$dir" '^OVERVIEW\.md  cannot read the "## Slices" table: no "What it does" column$' "Slices without its column"

dir=$(mktemp -d -p "$work"); write_overview "$dir"; write_invoice_readme "$dir"
sed 's/^| export-csv .*/| export-csv | Built | Export the ledger as one CSV |/' "$dir/OVERVIEW.md" >"$dir/o"; mv "$dir/o" "$dir/OVERVIEW.md"
cannot_render "$dir" '^OVERVIEW\.md  cannot read the "## Slices" table: line [0-9]+ has 3 cells, the header 4$' "a short Slices row"

dir=$(mktemp -d -p "$work"); write_overview "$dir"
printf '# invoice-cli\n\n%s\n\n## License\n' "$start_line" >"$dir/README.md"
cannot_render "$dir" '^README\.md  zuko:start without zuko:end$' "start without end"

dir=$(mktemp -d -p "$work"); write_overview "$dir"
printf '# invoice-cli\n%s\n\n## License\n' '<!-- zuko:end -->' >"$dir/README.md"
cannot_render "$dir" '^README\.md  zuko:end without zuko:start$' "end without start"

dir=$(mktemp -d -p "$work"); write_overview "$dir"
printf '# invoice-cli\n%s\n%s\ntext\n%s\n%s\n' "$start_line" '<!-- zuko:end -->' "$start_line" '<!-- zuko:end -->' >"$dir/README.md"
cannot_render "$dir" '^README\.md  two zuko blocks — zuko:start at lines 2 and 5$' "two blocks"

# A marker line in the description would become a second marker in README.md,
# and no later --write could repair it.
for marker in '<!-- zuko:end -->' "$start_line"; do
  dir=$(mktemp -d -p "$work"); write_overview "$dir"; write_invoice_readme "$dir"
  awk -v m="$marker" '{ print } /^\*\*Status:\*\*/ { print ""; print m }' "$dir/OVERVIEW.md" >"$dir/o"; mv "$dir/o" "$dir/OVERVIEW.md"
  cannot_render "$dir" '^OVERVIEW\.md  description holds a zuko marker line$' "marker in description (${marker:5:10})"
done

# README.md or OVERVIEW.md as a symlink could reach anywhere on disk.
dir=$(mktemp -d -p "$work"); write_overview "$dir"; write_invoice_readme "$dir"
mv "$dir/README.md" "$dir/real.md"; ln -s "$dir/real.md" "$dir/README.md"
cp "$dir/real.md" "$dir/real.before"
cannot_render "$dir" '^README\.md  is a symlink — not read$' "symlinked README"
expect_match '^yes$' "$(same_bytes "$dir/real.before" "$dir/real.md")" "symlinked README: its target is untouched"

dir=$(mktemp -d -p "$work"); write_overview "$dir"; write_invoice_readme "$dir"
mv "$dir/OVERVIEW.md" "$dir/real.md"; ln -s "$dir/real.md" "$dir/OVERVIEW.md"
cannot_render "$dir" '^OVERVIEW\.md  is a symlink — not read$' "symlinked overview"

# Arguments: one flag at most, and only a known one.
dir=$(mktemp -d -p "$work"); write_overview "$dir"; write_invoice_readme "$dir"
render "$dir" --force
expect_exit 2 "$status" "unknown flag: exits 2"
expect_match '^usage: render-readme-block\.sh \[--write\|--check\]$' "$out" "unknown flag: prints the usage line"
out=$(cd "$dir" && CLAUDE_PROJECT_DIR="$dir" bash "$scripts/render-readme-block.sh" --write --check 2>&1); status=$?
expect_exit 2 "$status" "two flags: exits 2"
expect_match '^usage: ' "$out" "two flags: prints the usage line"

rm -rf "$work"
