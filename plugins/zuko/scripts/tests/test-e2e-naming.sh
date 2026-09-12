# One walk through the whole slice: the hook at commit time, the gate before
# the PR. Sourced by run.sh, which provides $scripts and the expect_* helpers.

work=$(mktemp -d)
repo="$work/repo"
mkdir -p "$repo/docs/specs"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester

cat >"$repo/docs/specs/naming.md" <<'SPEC'
# Naming

| | |
| --- | --- |
| **Rollout** | No flag. Revert the merge commit. |
| **Proof it works** | The gate exits 0 with a scope line. |

**E2E:** this file.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
| O1 | Nothing is unresolved. | question | e2e | user | Resolved | Yes. |
SPEC
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "chore(spec): add the naming spec"
git -C "$repo" checkout -q -b feat/ship-naming

# The harness path: the hook judges the command, and only a clean verdict
# reaches git.
commit_through_hook() {   # commit_through_hook <message>; sets $hook_status
  local command payload
  echo "$RANDOM" >>"$repo/work.txt"
  git -C "$repo" add -A
  command="git commit -m \"$1\""
  payload=$(ZUKO_CMD="$command" python3 -c 'import json,os; print(json.dumps({"tool_input":{"command":os.environ["ZUKO_CMD"]}}))')
  printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$repo" bash "$scripts/block-attribution.sh" >/dev/null 2>&1
  hook_status=$?
  [ "$hook_status" -eq 0 ] && git -C "$repo" commit -q --no-verify -m "$1"
  return 0
}

gate() {
  gate_out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/verify-ship-gates.sh" docs/specs/naming.md 2>&1)
  gate_status=$?
}

# 1. A clean conventional commit goes through.
commit_through_hook "feat(ship): standardise git naming"
expect_exit 0 "$hook_status" "e2e: the hook lets a clean commit through"
expect_match 'feat\(ship\): standardise git naming' "$(git -C "$repo" log -1 --format=%s)" "e2e: the clean commit landed"

# 2. A signed one does not.
before=$(git -C "$repo" rev-list --count HEAD)
commit_through_hook "feat(ship): sign it

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
expect_exit 2 "$hook_status" "e2e: the hook blocks a signed commit"
expect_exit "$before" "$(git -C "$repo" rev-list --count HEAD)" "e2e: no commit was created"
git -C "$repo" reset -q --hard   # the blocked change never lands

# 3. The gate passes the branch and says what it scanned.
gate
expect_exit 0 "$gate_status" "e2e: the gate passes a clean branch"
expect_match '^Naming: checked 1 commits on feat/ship-naming ahead of main\.$' "$gate_out" "e2e: the gate prints the scope it scanned"

# 4. A commit that broke the format after the fact is caught before the PR.
echo late >>"$repo/work.txt"
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "Standardise git naming"
late_sha=$(git -C "$repo" log -1 --format=%h)
gate
expect_exit 1 "$gate_status" "e2e: the gate rejects a branch that broke the format"
expect_match "$late_sha  subject is not" "$gate_out" "e2e: the gate names the offending commit by short SHA"

rm -rf "$work"
