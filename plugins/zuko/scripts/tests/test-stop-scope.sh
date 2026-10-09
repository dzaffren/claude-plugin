# scripts/lib/stop_scope.py, through both Stop hooks -- they judge only the
# zuko docs that this branch or the working tree changed.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

# git reads this machine's global config (insteadOf rules, hook paths,
# signing) from HOME; the scratch repos get an empty one.
export HOME="$work/stop-scope-home" XDG_CONFIG_HOME="$work/stop-scope-home/.config" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME"

g() { git -C "$repo" -c user.name=Zuko -c user.email=zuko@example.com -c commit.gpgsign=false "$@"; }

new_repo() {   # a git repo on main with one commit; path in $repo
  repo=$(mktemp -d -p "$work")
  git init -q -b main "$repo"
  mkdir -p "$repo/docs/specs" "$repo/src/pages"
  echo "# Raslaw" >"$repo/README.md"
  g add -A
  g commit -q -m "chore: start"
}

zuko_spec() {  # zuko_spec <path under docs/specs> <status> <row id> <row status>
  mkdir -p "$(dirname "$repo/docs/specs/$1")"
  cat >"$repo/docs/specs/$1" <<EOF
# Reach the firm

**Version:** v1 · **Status:** $2 · **Type:** Feature · **Project type:** Web UI

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
| $3 | Does SMTP_PASSWORD survive a deploy? | unproven | build | user | $4 | — |
EOF
}

shape() {      # shape <path under docs/specs> <status> <row id> <row status>
  mkdir -p "$(dirname "$repo/docs/specs/$1")"
  cat >"$repo/docs/specs/$1" <<EOF
# Billing

**Project type:** Web UI · **Status:** $2

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
| $3 | Who can refund? | question | shape | user | $4 | — |
EOF
}

runbook() {    # a runbook: a Status line, no Version line, no ledger
  mkdir -p "$repo/docs/specs/raslaw-rebuild"
  printf '# Cutover runbook\n\n**Status:** Shipped · **For:** slice 5b\n\n1. Point the domain.\n' \
    >"$repo/docs/specs/raslaw-rebuild/5b-cutover-runbook.md"
}

other_tool_spec() {   # another tool's spec: Ticket first, no ledger
  mkdir -p "$repo/docs/specs/TBD-security-audit-v1-2-0"
  printf '# Rate limiting\n\n**Ticket:** TBD · **Type:** Feature · **Version:** v1 · **Status:** Built\n\n## Goals\n' \
    >"$repo/docs/specs/TBD-security-audit-v1-2-0/spec-rate-limiting-and-input-bounds.md"
}

payload='{"session_id":"stop-scope","transcript_path":"/dev/null","cwd":"/","permission_mode":"default","hook_event_name":"Stop","stop_hook_active":false}'

hooks() {      # both Stop hooks over $repo; sets vg_out vg_status oi_out oi_status
  vg_out=$(CLAUDE_PROJECT_DIR="$repo" bash "$scripts/verify-gates.sh" <<<"$payload" 2>&1)
  vg_status=$?
  oi_out=$(CLAUDE_PROJECT_DIR="$repo" bash "$scripts/check-open-items.sh" <<<"$payload" 2>&1)
  oi_status=$?
}

# 1. A runbook under docs/specs is never judged, even when the branch changed it.
new_repo; g switch -q -c fix/contact-form
runbook; g add -A; g commit -q -m "docs: cutover runbook"
hooks
expect_exit 0 "$vg_status" "runbook on the branch: verify-gates passes"
expect_exit 0 "$oi_status" "runbook on the branch: check-open-items passes"

# 2. Another tool's spec is never judged, even new and untracked.
new_repo; other_tool_spec
hooks
expect_exit 0 "$vg_status" "other tool's spec, untracked: verify-gates passes"
expect_exit 0 "$oi_status" "other tool's spec, untracked: check-open-items passes"

# 3. An old breach on main is ignored when the branch never touched it.
new_repo
zuko_spec raslaw-rebuild/1-reach-the-firm.md Built O19 Open; g add -A; g commit -q -m "docs: reach the firm"
g switch -q -c fix/contact-form
echo '<form></form>' >"$repo/src/pages/contact.astro"; g add -A; g commit -q -m "fix: contact form"
hooks
expect_exit 0 "$vg_status" "untouched breach: verify-gates passes"
expect_exit 0 "$oi_status" "untouched breach: check-open-items passes"

# 4. A zuko spec the branch committed is judged, nested or not; the old breach
#    on main is still not named. An archived copy is never judged.
zuko_spec raslaw-rebuild/8-the-site-follows-the-bars-publicity-rules.md Refined O3 Open
zuko_spec archive/reach-the-firm-v1.md Refined O7 Open
g add -A; g commit -q -m "docs: publicity rules"
hooks
expect_exit 2 "$oi_status" "committed nested spec: check-open-items exits 2"
expect_match '8-the-site-follows-the-bars-publicity-rules\.md is .Refined.' "$oi_out" \
  "committed nested spec: names the spec and 'Refined'"
expect_match '\| O3 \|' "$oi_out" "committed nested spec: names row O3"
expect_no_match '1-reach-the-firm\.md' "$oi_out" "committed nested spec: the untouched breach is not named"
expect_no_match 'archive/' "$oi_out" "committed nested spec: the archived copy is not named"
zuko_spec raslaw-rebuild/8-the-site-follows-the-bars-publicity-rules.md Refining O3 Resolved
g add -A; g commit -q -m "docs: publicity rules status"
hooks
expect_exit 2 "$vg_status" "bad status on the branch: verify-gates exits 2"
expect_match "8-the-site-follows-the-bars-publicity-rules\.md has Status 'Refining'" "$vg_out" \
  "bad status on the branch: verify-gates names the spec and the status"
expect_no_match '1-reach-the-firm\.md' "$vg_out" "bad status on the branch: the untouched spec is not named"

# 5. On main, an uncommitted change is judged; staged and untracked too.
new_repo
shape billing/shape.md Shaping O2 Open; g add -A; g commit -q -m "docs: billing shape"
shape billing/shape.md Shaped O2 Open
hooks
expect_exit 2 "$oi_status" "uncommitted on main: check-open-items exits 2"
expect_match 'billing/shape\.md is .Shaped.' "$oi_out" "uncommitted on main: names the shape and 'Shaped'"
expect_match '\| O2 \|' "$oi_out" "uncommitted on main: names row O2"
shape billing/shape.md Shaping O2 Open
zuko_spec refunds.md Refined O4 Open; g add docs/specs/refunds.md
hooks
expect_exit 2 "$oi_status" "staged on main: check-open-items exits 2"
expect_match 'refunds\.md is .Refined.' "$oi_out" "staged on main: names the staged spec"
expect_no_match 'billing/shape\.md' "$oi_out" "staged on main: the shape set back to Shaping is not named"
g reset -q docs/specs/refunds.md
hooks
expect_exit 2 "$oi_status" "untracked on main: check-open-items exits 2"
expect_match 'refunds\.md is .Refined.' "$oi_out" "untracked on main: names the new spec"

# A doc the helper cannot read fails both gates with the reason; it never
# passes unjudged. (Root can read anything, so this case needs a normal user.)
if [ "$(id -u)" -ne 0 ]; then
  chmod 000 "$repo/docs/specs/refunds.md"
  hooks
  chmod 644 "$repo/docs/specs/refunds.md"
  expect_exit 2 "$vg_status" "unreadable doc: verify-gates exits 2"
  expect_match 'could not be listed: .*refunds\.md' "$vg_out" "unreadable doc: verify-gates says why"
  expect_exit 2 "$oi_status" "unreadable doc: check-open-items exits 2"
  expect_match 'could not be listed: .*refunds\.md' "$oi_out" "unreadable doc: check-open-items says why"
fi

# E2E: one repo walks the slice. main holds an old breach; the branch adds a
# runbook and another tool's spec, and both hooks pass. Then the branch commits
# a nested zuko spec with an Open row, and only that spec is named.
new_repo
zuko_spec raslaw-rebuild/1-reach-the-firm.md Built O19 Open; g add -A; g commit -q -m "docs: reach the firm"
g switch -q -c fix/contact-form
runbook; other_tool_spec; g add -A; g commit -q -m "docs: runbook and audit notes"
echo '<form></form>' >"$repo/src/pages/contact.astro"
hooks
expect_exit 0 "$vg_status" "e2e: foreign docs and an old breach, verify-gates passes"
expect_exit 0 "$oi_status" "e2e: foreign docs and an old breach, check-open-items passes"
zuko_spec raslaw-rebuild/8-the-site-follows-the-bars-publicity-rules.md Refined O3 Open
g add -A; g commit -q -m "docs: publicity rules"
hooks
expect_exit 0 "$vg_status" "e2e: the new spec is well formed, verify-gates passes"
expect_exit 2 "$oi_status" "e2e: the new spec has an Open row, check-open-items exits 2"
expect_match '8-the-site-follows-the-bars-publicity-rules\.md is .Refined.' "$oi_out" "e2e: names the new spec"
expect_no_match '1-reach-the-firm|5b-cutover|spec-rate-limiting' "$oi_out" "e2e: names nothing else"
