# scripts/check-open-items.sh -- the open-items gate, hook mode and direct mode.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

# new_repo: an empty scratch project with docs/specs/, path in $repo.
new_repo() {
  repo=$(mktemp -d -p "$work")
  mkdir -p "$repo/docs/specs"
}

# write_doc <path> <status> <row status>: a shape or spec with one ledger row O4.
write_doc() {
  mkdir -p "$(dirname "$1")"
  cat >"$1" <<EOF
# Refunds

**Version:** v1 · **Status:** $2 · **Type:** Feature

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
| O4 | Who can refund? | question | shape | user | $3 | — |
EOF
}

gate() {        # gate: hook mode over $repo; sets $gate_out $gate_status
  gate_out=$(echo '{}' | CLAUDE_PROJECT_DIR="$repo" bash "$scripts/check-open-items.sh" 2>&1)
  gate_status=$?
}

# 1. A Shaped shape with an Open row fails; handed to a later slice, it passes.
new_repo; write_doc "$repo/docs/specs/v3-billing/shape.md" Shaped Open; gate
expect_exit 2 "$gate_status" "shaped shape, open row: exits 2"
expect_match 'v3-billing/shape\.md is .Shaped.' "$gate_out" "shaped shape, open row: names the shape and 'Shaped'"
expect_match '\| O4 \| Who can refund\?' "$gate_out" "shaped shape, open row: names row O4"
write_doc "$repo/docs/specs/v3-billing/shape.md" Shaped 'Handed to refunds'; gate
expect_exit 0 "$gate_status" "shaped shape, handed row: passes"
write_doc "$repo/docs/specs/v3-billing/shape.md" Shaping Open; gate
expect_exit 0 "$gate_status" "shaping shape, open row: passes"

# 2. A Refined spec with an Open row fails; at Draft it passes.
new_repo; write_doc "$repo/docs/specs/refunds.md" Refined Open; gate
expect_exit 2 "$gate_status" "refined spec, open row: exits 2"
expect_match 'docs/specs/refunds\.md is .Refined.' "$gate_out" "refined spec, open row: names the spec and 'Refined'"
expect_match '\| O4 \| Who can refund\?' "$gate_out" "refined spec, open row: names the row"
expect_match '^Open-items gate failed\. A shape cannot be Shaped, and a spec cannot be Refined,$' "$gate_out" \
  "refined spec, open row: the new header"
expect_match 'or in a shape hand it to a later slice\. Never delete a row\.' "$gate_out" \
  "refined spec, open row: the footer names handing"
write_doc "$repo/docs/specs/refunds.md" Draft Open; gate
expect_exit 0 "$gate_status" "draft spec, open row: passes"

# 3. Built and Shipped still fail, as before.
for status in Built Shipped; do
  new_repo; write_doc "$repo/docs/specs/refunds.md" "$status" Open; gate
  expect_exit 2 "$gate_status" "$(echo "$status" | tr 'A-Z' 'a-z') spec, open row: exits 2"
done

# 4. Resolved and Accepted risk pass at Refined.
new_repo; write_doc "$repo/docs/specs/refunds.md" Refined Resolved; gate
expect_exit 0 "$gate_status" "refined spec, resolved row: passes"
write_doc "$repo/docs/specs/refunds.md" Refined 'Accepted risk'; gate
expect_exit 0 "$gate_status" "refined spec, accepted-risk row: passes"

# 5. End to end in one repo: the shape hands O4, the spec picks it up as Open
#    and cannot be Refined, then resolving it lets the spec through.
new_repo
write_doc "$repo/docs/specs/v3-billing/shape.md" Shaped 'Handed to refunds'; gate
expect_exit 0 "$gate_status" "e2e: the shape with a handed row passes"
write_doc "$repo/docs/specs/refunds.md" Refined Open; gate
expect_exit 2 "$gate_status" "e2e: the spec holding the row as Open fails at Refined"
expect_no_match 'shape\.md' "$gate_out" "e2e: the handed shape is not reported"
write_doc "$repo/docs/specs/refunds.md" Refined Resolved; gate
expect_exit 0 "$gate_status" "e2e: the row resolved, the spec passes"

# 6. A second Stop in the same turn never loops.
new_repo; write_doc "$repo/docs/specs/refunds.md" Refined Open
out=$(echo '{"stop_hook_active": true}' | CLAUDE_PROJECT_DIR="$repo" bash "$scripts/check-open-items.sh" 2>&1)
expect_exit 0 "$?" "stop_hook_active: exits 0"

# 7. Direct mode, unchanged: lists open rows at any status, exit 1.
new_repo; write_doc "$repo/docs/specs/refunds.md" Draft Open
out=$(bash "$scripts/check-open-items.sh" "$repo/docs/specs/refunds.md" 2>&1); status=$?
expect_exit 1 "$status" "direct, open row: exits 1"
expect_match '/build cannot start' "$out" "direct, open row: says /build cannot start"
write_doc "$repo/docs/specs/refunds.md" Draft Resolved
out=$(bash "$scripts/check-open-items.sh" "$repo/docs/specs/refunds.md" 2>&1); status=$?
expect_exit 0 "$status" "direct, no open row: exits 0"
out=$(bash "$scripts/check-open-items.sh" "$repo/docs/specs/missing.md" 2>&1); status=$?
expect_exit 1 "$status" "direct, missing path: exits 1"
