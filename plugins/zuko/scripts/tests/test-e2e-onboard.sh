# One walk through the auto-onboard slice: the session loader and the ship
# gate over the life of one repo's overview. Sourced by run.sh, which provides
# $scripts and the expect_* helpers.

work=$(mktemp -d)
repo="$work/repo"
mkdir -p "$repo/docs/specs"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester

# A spec that clears every other gate, so each failure below is the overview.
cat >"$repo/docs/specs/export-csv.md" <<'SPEC'
# Export CSV

| | |
| --- | --- |
| **Rollout** | No flag. Revert the merge commit. |
| **Proof it works** | The gate exits 0 with an overview scope line. |

**E2E:** this file.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
| O1 | Nothing is unresolved. | question | e2e | user | Resolved | Yes. |
SPEC
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "chore(spec): add the export-csv spec"
git -C "$repo" checkout -q -b feat/export-csv
echo work >"$repo/work.txt"
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "feat(export): write the ledger as one CSV"

write_overview() {   # write_overview <status> <slices rows>; commits it
  cat >"$repo/OVERVIEW.md" <<OVERVIEW
# invoice-cli

**Status:** $1 · **Updated:** 2026-09-24 by /spec export-csv

Turns a folder of supplier invoices into one ledger CSV.

## Slices

| Slice | Status | What it does | Page |
| ----- | ------ | ------------ | ---- |
$2

## More

README.md
OVERVIEW
  git -C "$repo" add -A
  git -C "$repo" commit -q --no-verify -m "docs(overview): update the overview"
}

load() {
  load_out=$(CLAUDE_PROJECT_DIR="$repo" bash "$scripts/load-overview.sh" 2>&1)
  load_status=$?
}

gate() {
  gate_out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/verify-ship-gates.sh" docs/specs/export-csv.md 2>&1)
  gate_status=$?
}

# 1. Not onboarded.
load
expect_exit 0 "$load_status" "e2e: the loader never blocks a session"
expect_match '^No OVERVIEW\.md — the next zuko stage will onboard this repo\.$' "$load_out" "e2e: the loader prints the onboard hint"
gate
expect_exit 1 "$gate_status" "e2e: the gate refuses a repo with no overview"
expect_match 'OVERVIEW\.md  not onboarded' "$gate_out" "e2e: the gate says not onboarded"

# 2. Onboarded, still Draft.
write_overview Draft "| import-csv | Refined | Import last month's ledger | https://claude.ai/... |"
load
expect_match '^Project overview \(OVERVIEW\.md\) — Draft — not yet confirmed:$' "$load_out" "e2e: the loader flags the Draft"
gate
expect_exit 1 "$gate_status" "e2e: the gate refuses a Draft overview"
expect_match 'OVERVIEW\.md  overview still Draft' "$gate_out" "e2e: the gate says still Draft"

# 3. Approved, but the slice has no row.
write_overview Active "| import-csv | Refined | Import last month's ledger | https://claude.ai/... |"
load
expect_match '^Project overview \(OVERVIEW\.md\):$' "$load_out" "e2e: the loader loads the Active overview"
gate
expect_exit 1 "$gate_status" "e2e: the gate refuses a slice missing from the table"
expect_match 'OVERVIEW\.md  slices table has no row for "export-csv"' "$gate_out" "e2e: the gate names the missing slice"

# 4. The row is added: the branch ships.
write_overview Active "| export-csv | Built | Export the ledger as one CSV | https://claude.ai/... |
| import-csv | Refined | Import last month's ledger | https://claude.ai/... |"
gate
expect_exit 0 "$gate_status" "e2e: the gate passes once the slice has its row"
expect_match '^Overview: row for "export-csv" found$' "$gate_out" "e2e: the gate prints the overview scope line"

# 5. The overview grows past the cap.
i=0
while [ "$i" -lt 180 ]; do echo "- padding line $i"; i=$((i + 1)); done >>"$repo/OVERVIEW.md"
head -n 180 "$repo/OVERVIEW.md" >"$work/trimmed" && mv "$work/trimmed" "$repo/OVERVIEW.md"
load
expect_exit 0 "$load_status" "e2e: a long overview still loads"
expect_match '^Warning: OVERVIEW\.md is 180 lines; loaded the first 150\. Trim it to 150\.$' "$load_out" "e2e: the loader warns on a 180-line overview"

rm -rf "$work"
