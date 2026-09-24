# One walk through the decision-log slice: seven recorded decisions, the
# session loader, a supersede, and the ship gate refusing a rewritten history.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

work=$(mktemp -d)
repo="$work/repo"
mkdir -p "$repo/docs/specs"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester

# A spec, overview and README that clear every other gate, so each failure
# below is DECISIONS.md.
cat >"$repo/docs/specs/offline-mode.md" <<'SPEC'
# Offline mode

| | |
| --- | --- |
| **Rollout** | No flag. Revert the merge commit. |
| **Proof it works** | The gate prints the decisions scope line. |

**E2E:** this file.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
| O1 | Nothing is unresolved. | question | e2e | user | Resolved | Yes. |
SPEC
cat >"$repo/OVERVIEW.md" <<'OVERVIEW'
# invoice-cli

**Status:** Active · **Updated:** 2026-09-24 by /spec offline-mode

Turns a folder of supplier invoices into one ledger CSV.

## Run it

| Task    | Command            |
| ------- | ------------------ |
| install | `pip install -e .` |

## Slices

| Slice        | Status | What it does                | Page                  |
| ------------ | ------ | --------------------------- | --------------------- |
| offline-mode | Built  | Import invoices with no net | https://claude.ai/... |
OVERVIEW
cat >"$repo/DECISIONS.md" <<'DECISIONS'
# Decisions

Append-only. A changed decision is a new entry that supersedes the old one; only an
old entry's Status line ever changes.
DECISIONS
for n in 1 2 3 4 5 6; do
  printf '\n## D%s · 2026-09-24 · Choice %s\n\nWhy: reason %s, measured at 40 seconds.\nRejected: option %s (slower).\nSource: specs/slice-%s.md\nStatus: active\n' \
    "$n" "$n" "$n" "$n" "$n" >>"$repo/DECISIONS.md"
done
cat >>"$repo/DECISIONS.md" <<'D7'

## D7 · 2026-09-24 · Use Postgres, not SQLite

Why: two finance users import at month end at the same time; SQLite locks the whole
file on write.
Rejected: SQLite (whole-file write lock), DynamoDB (cost for under 1 GB of data).
Source: specs/import-csv.md
Status: active
D7
printf '# invoice-cli\n\n<!-- zuko:start — generated from OVERVIEW.md; edit that file, not this block -->\n<!-- zuko:end -->\n' >"$repo/README.md"
CLAUDE_PROJECT_DIR="$repo" bash "$scripts/render-readme-block.sh" --write 2>/dev/null
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "chore(spec): add the offline-mode spec"
git -C "$repo" checkout -q -b feat/offline-mode
cp "$repo/DECISIONS.md" "$work/DECISIONS.recorded"

load() {
  load_out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/load-decisions.sh" 2>&1)
  load_status=$?
}

gate() {
  gate_out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/verify-ship-gates.sh" docs/specs/offline-mode.md 2>&1)
  gate_status=$?
}

commit() {      # commit <subject>
  git -C "$repo" add -A
  git -C "$repo" commit -q --no-verify -m "$1"
}

# 1. A new session sees the seven active titles and nothing more.
load
expect_exit 0 "$load_status" "e2e: the loader never blocks a session"
expect_match '^  D7  Use Postgres, not SQLite$' "$load_out" "e2e: the loader lists D7"
expect_match '^8$' "$(printf '%s\n' "$load_out" | wc -l | tr -d ' ')" "e2e: header plus 7 titles"
expect_no_match 'Why:|Rejected:' "$load_out" "e2e: no bodies at session start"

# 2. /spec supersedes D7: D8 appended, D7's Status line the only change.
awk '
  /^## D/ { in7 = ($0 ~ /^## D7 · /) }
  in7 && /^Status: active$/ { print "Status: superseded by D8"; next }
  { print }' "$work/DECISIONS.recorded" >"$repo/DECISIONS.md"
cat >>"$repo/DECISIONS.md" <<'D8'

## D8 · 2026-09-24 · Postgres on the server, SQLite for the laptop cache

Why: offline mode needs a local store with transactions; the laptop never has a second
writer, while the server still has two month-end importers.
Rejected: IndexedDB (no Python client), JSON files (no transactions).
Supersedes: D7
Source: specs/offline-mode.md
Status: active
D8
commit "feat(store): cache imports locally in SQLite"
cp "$repo/DECISIONS.md" "$work/DECISIONS.superseded"
gate
expect_exit 0 "$gate_status" "e2e: the gate passes a correct supersede"
expect_match '^Decisions: 8 entries checked against main$' "$gate_out" "e2e: the gate prints the decisions scope line"
load
expect_match '^  D8  Postgres on the server, SQLite for the laptop cache$' "$load_out" "e2e: the loader lists D8"
expect_no_match '^  D7 ' "$load_out" "e2e: the loader drops superseded D7"

# 3. Someone rewrites D3's Why instead of superseding it.
sed 's/^Why: reason 3, measured at 40 seconds\.$/Why: reason 3, measured at 4 seconds./' \
  "$work/DECISIONS.superseded" >"$repo/DECISIONS.md"
commit "docs: correct D3"
gate
expect_exit 1 "$gate_status" "e2e: the gate refuses an edited D3"
expect_match '^- DECISIONS\.md  D3 changed after it was recorded — only its Status line may change; supersede it with a new entry$' \
  "$gate_out" "e2e: the gate names D3 and the fix"

# 4. Reverted: the gate passes again.
cp "$work/DECISIONS.superseded" "$repo/DECISIONS.md"
commit "docs: restore D3"
gate
expect_exit 0 "$gate_status" "e2e: the gate passes once D3 is restored"

# 5. Someone deletes D5.
awk '/^## D5 · /{skip=1} /^## D6 · /{skip=0} !skip' "$work/DECISIONS.superseded" >"$repo/DECISIONS.md"
commit "docs: drop D5"
gate
expect_exit 1 "$gate_status" "e2e: the gate refuses a deleted D5"
expect_match '^- DECISIONS\.md  D5 was removed after it was recorded — supersede it with a new entry instead$' \
  "$gate_out" "e2e: the gate names D5"

rm -rf "$work"
