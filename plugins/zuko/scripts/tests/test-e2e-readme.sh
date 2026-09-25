# One walk through the readme-block slice: onboarding's approved merge, a
# slice shipping, the ship gate refusing the stale block, the re-render, and a
# formatter re-padding the table. Sourced by run.sh, which provides $scripts
# and the expect_* helpers.

work=$(mktemp -d)
repo="$work/repo"
mkdir -p "$repo/docs/specs"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester

# The user's README, before onboarding: a title, an Install section the block
# overlaps, and a License section that is theirs.
cat >"$repo/README.md" <<'README'
# invoice-cli

Turns supplier invoices into a ledger.

## Install

```
pip install -e .
```

## License

MIT. See LICENSE.
README
cp "$repo/README.md" "$work/README.original"

# A spec that clears every other gate, so each failure below is the README.
cat >"$repo/docs/specs/export-csv.md" <<'SPEC'
# Export CSV

| | |
| --- | --- |
| **Rollout** | No flag. Revert the merge commit. |
| **Proof it works** | The gate prints the README scope line. |

**E2E:** this file.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
| O1 | Nothing is unresolved. | question | e2e | user | Resolved | Yes. |
SPEC
cat >"$repo/DECISIONS.md" <<'DECISIONS'
# Decisions

Append-only. A changed decision is a new entry that supersedes the old one; only an
old entry's Status line ever changes.
DECISIONS
python3 "$scripts/lib/changelog.py" init "$repo" >/dev/null
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "chore(spec): add the export-csv spec"
git -C "$repo" checkout -q -b feat/export-csv
echo work >"$repo/work.txt"
printf '\n### Added\n\n- Export the ledger as one CSV file.\n' >>"$repo/CHANGELOG.md"
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "feat(export): write the ledger as one CSV"

write_overview() {   # write_overview <export-csv status> <what it does>
  cat >"$repo/OVERVIEW.md" <<OVERVIEW
# invoice-cli

**Status:** Active · **Updated:** 2026-09-24 by /spec export-csv

Turns a folder of supplier invoices into one ledger CSV.

## Run it

| Task    | Command            |
| ------- | ------------------ |
| install | \`pip install -e .\` |

## Slices

| Slice      | Status | What it does | Page                  |
| ---------- | ------ | ------------ | --------------------- |
| export-csv | $1 | $2 | https://claude.ai/... |
OVERVIEW
}

render() {      # render <flag>; sets $render_status
  CLAUDE_PROJECT_DIR="$repo" bash "$scripts/render-readme-block.sh" "$1" 2>/dev/null
  render_status=$?
}

gate() {
  gate_out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/verify-ship-gates.sh" docs/specs/export-csv.md 2>&1)
  gate_status=$?
}

commit() {      # commit <subject>
  git -C "$repo" add -A
  git -C "$repo" commit -q --no-verify -m "$1"
}

# README.md with the lines between the markers left out.
outside() {     # outside <file>
  awk '/^<!-- zuko:end -->$/ { inside = 0 } !inside { print } /^<!-- zuko:start/ { inside = 1 }' "$1"
}

inside() {      # inside <file>
  awk '/^<!-- zuko:end -->$/ { inside = 0 } inside { print } /^<!-- zuko:start/ { inside = 1 }' "$1"
}

# From "## License" to the end of the file.
license() {     # license <file>
  sed -n '/^## License$/,$p' "$1"
}

# 1. Onboarding: the overview is written, and the approved merge replaces the
# Install section with an empty marker pair; the renderer fills it.
write_overview Built "Export the ledger as one CSV"
awk '
  /^## Install$/ {
    print "<!-- zuko:start — generated from OVERVIEW.md; edit that file, not this block -->"
    print "<!-- zuko:end -->"
    print ""
    skipping = 1
    next
  }
  skipping && /^## / { skipping = 0 }
  !skipping { print }
' "$work/README.original" >"$repo/README.md"
outside "$repo/README.md" >"$work/outside.merged"
render --write
expect_exit 0 "$render_status" "e2e: the renderer fills the empty marker pair"
expect_no_match '^## Install$' "$(cat "$repo/README.md")" "e2e: the Install section is gone"
expect_match '^\| install +\| `pip install -e \.` +\|$' "$(inside "$repo/README.md")" "e2e: the block holds the install command"
expect_match '^Nothing shipped yet$' "$(inside "$repo/README.md")" "e2e: a Built slice is not a feature yet"
outside "$repo/README.md" >"$work/outside.written"
cmp -s "$work/outside.merged" "$work/outside.written"
expect_exit 0 "$?" "e2e: every line outside the markers is byte-identical"
license "$work/README.original" >"$work/license.original"
license "$repo/README.md" >"$work/license.written"
cmp -s "$work/license.original" "$work/license.written"
expect_exit 0 "$?" "e2e: the License section is byte-identical to the user's"
commit "docs(readme): move the install steps into the zuko block"
gate
expect_exit 0 "$gate_status" "e2e: the gate passes the freshly rendered block"

# 2. The slice ships: the overview row flips, and nobody re-renders.
write_overview Shipped "Export the ledger as one CSV"
commit "docs(overview): mark export-csv shipped"
gate
expect_exit 1 "$gate_status" "e2e: the gate refuses the stale block"
expect_match '^- README\.md  zuko block is stale — run render-readme-block\.sh --write$' "$gate_out" "e2e: the gate names the stale block and the fix"

# 3. /ship's close-out re-renders: the gate passes and the feature is listed.
render --write
commit "docs(readme): re-render the zuko block"
gate
expect_exit 0 "$gate_status" "e2e: the gate passes the re-rendered block"
expect_match '^README: zuko block matches OVERVIEW\.md$' "$gate_out" "e2e: the gate prints the README scope line"
expect_match '^- Export the ledger as one CSV$' "$(inside "$repo/README.md")" "e2e: the shipped slice is a feature"
outside "$repo/README.md" >"$work/outside.rerendered"
cmp -s "$work/outside.merged" "$work/outside.rerendered"
expect_exit 0 "$?" "e2e: the re-render leaves every outside byte alone"

# 4. A formatter re-pads the block's table: other widths, a bare separator.
cp "$repo/README.md" "$work/README.rendered"
sed -E -e 's/^\| -+ \| -+ \|$/|---|---|/' -e '/^\|/s/ +\|/ |/g' "$work/README.rendered" >"$repo/README.md"
expect_match '^\|---\|---\|$' "$(cat "$repo/README.md")" "e2e: the formatter rewrote the separator"
expect_match '^\| Task \| Command \|$' "$(cat "$repo/README.md")" "e2e: the formatter changed the padding"
commit "docs(readme): format the tables"
gate
expect_exit 0 "$gate_status" "e2e: the gate still passes a re-padded table"
expect_match '^README: zuko block matches OVERVIEW\.md$' "$gate_out" "e2e: the re-padded block still matches"

rm -rf "$work"
