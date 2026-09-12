# scripts/verify-ship-gates.sh -- the branch-wide naming check.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

work=$(mktemp -d)

# A spec that clears every gate except the ones each test is about, so a
# failure here is always the naming block talking.
write_spec() {
  mkdir -p "$1/docs/specs"
  cat >"$1/docs/specs/fixture.md" <<'SPEC'
# Fixture

| | |
| --- | --- |
| **Rollout** | No flag. Revert the merge commit. |
| **Proof it works** | The fixture asserts the exit code. |

**E2E:** tests/test-e2e-naming.sh

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
| O1 | Nothing is unresolved. | question | fixture | user | Resolved | Yes. |
SPEC
}

new_repo() {   # new_repo <branch> [--no-base]; prints the repo path
  local dir base_branch=main
  dir=$(mktemp -d -p "$work")
  [ "${2:-}" = "--no-base" ] && base_branch="$1"
  git -C "$dir" init -q -b "$base_branch"
  git -C "$dir" config user.email t@example.com
  git -C "$dir" config user.name Tester
  write_spec "$dir"
  git -C "$dir" add -A
  git -C "$dir" commit -q --no-verify -m "chore(spec): add the fixture spec"
  [ "$base_branch" = "$1" ] || git -C "$dir" checkout -q -b "$1"
  printf '%s' "$dir"
}

add_commit() {  # add_commit <repo> <subject> [body]
  echo "$RANDOM" >>"$1/work.txt"
  git -C "$1" add -A
  if [ -n "${3:-}" ]; then
    git -C "$1" commit -q --no-verify -m "$2" -m "$3"
  else
    git -C "$1" commit -q --no-verify -m "$2"
  fi
}

sha_of() { git -C "$1" log -1 --format=%h; }

gate() {        # gate <repo>; sets $gate_out $gate_status
  gate_out=$(cd "$1" && CLAUDE_PROJECT_DIR="$1" bash "$scripts/verify-ship-gates.sh" docs/specs/fixture.md 2>&1)
  gate_status=$?
}

# 1. A clean branch.
repo=$(new_repo feat/ship-naming)
add_commit "$repo" "feat(ship): standardise git naming"
add_commit "$repo" "feat(scripts): add the attribution hook"
add_commit "$repo" "test(scripts): cover the naming gate"
gate "$repo"
expect_exit 0 "$gate_status" "a clean branch passes"
expect_match '^Naming: checked 3 commits on feat/ship-naming ahead of main\.$' "$gate_out" "the scope line names the count, the branch and the base"
expect_match 'Mechanical ship gates passed' "$gate_out" "a clean branch reports the pass"

# 2. One commit with a subject that is not conventional.
repo=$(new_repo feat/ship-naming)
add_commit "$repo" "feat(ship): standardise git naming"
add_commit "$repo" "Standardise git naming"
bad_sha=$(sha_of "$repo")
add_commit "$repo" "test(scripts): cover the naming gate"
gate "$repo"
expect_exit 1 "$gate_status" "a non-conventional subject fails the gate"
expect_match "1 of 3 commits break the naming convention" "$gate_out" "the count says how many of how many"
expect_match "$bad_sha  subject is not \{type\}\(\{scope\}\): \{subject\}" "$gate_out" "the offending commit is named by short SHA and rule"
expect_match '"Standardise git naming"' "$gate_out" "the offending subject is quoted back"

# 3. A commit carrying a Claude-Session trailer.
repo=$(new_repo feat/ship-naming)
add_commit "$repo" "feat(ship): standardise git naming" \
  "Claude-Session: https://claude.ai/code/session_01SXGpxYGgMK3E6G6kCNgi83"
gate "$repo"
expect_exit 1 "$gate_status" "a Claude-Session trailer fails the gate"
expect_match 'carries a Claude-Session trailer' "$gate_out" "the gate names the trailer rule"

# 4. Scenario 4 exactly: a bad subject and a trailer on the same branch.
repo=$(new_repo feat/ship-naming)
add_commit "$repo" "feat(ship): standardise git naming"
add_commit "$repo" "Standardise git naming"
subject_sha=$(sha_of "$repo")
add_commit "$repo" "test(scripts): cover the naming gate" \
  "Claude-Session: https://claude.ai/code/session_01SXGpxYGgMK3E6G6kCNgi83"
trailer_sha=$(sha_of "$repo")
gate "$repo"
expect_exit 1 "$gate_status" "two broken commits fail the gate"
expect_match "2 of 3 commits break the naming convention" "$gate_out" "both offenders are counted"
expect_match "$subject_sha" "$gate_out" "the bad subject's SHA is printed"
expect_match "$trailer_sha" "$gate_out" "the trailered commit's SHA is printed"

# 5. Nothing to check.
repo=$(new_repo feat/ship-naming)
gate "$repo"
expect_exit 1 "$gate_status" "an empty range fails the gate"
expect_match "No commits on 'feat/ship-naming' ahead of main\. A gate that scanned nothing is not a pass\." "$gate_out" "the empty range says it scanned nothing"
expect_no_match 'gates passed' "$gate_out" "the gate never reports a pass on a scope it did not scan"

# 6. A branch that is not {type}/{slice}.
repo=$(new_repo ship-naming)
add_commit "$repo" "feat(ship): standardise git naming"
gate "$repo"
expect_exit 1 "$gate_status" "a branch without a type fails the gate"
expect_match "Branch 'ship-naming' is not \{type\}/\{slice\}\. Types: feat fix chore docs refactor test\." "$gate_out" "the branch rule names the allowed types"

# 7. A subject over 72 characters.
repo=$(new_repo feat/ship-naming)
add_commit "$repo" "feat(ship): standardise every last piece of git naming across the whole plugin"
gate "$repo"
expect_exit 1 "$gate_status" "an over-long subject fails the gate"
expect_match 'subject is longer than 72 characters' "$gate_out" "the gate names the length rule"

# 8. A Co-Authored-By trailer naming Claude.
repo=$(new_repo feat/ship-naming)
add_commit "$repo" "feat(ship): standardise git naming" \
  "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
gate "$repo"
expect_exit 1 "$gate_status" "a Co-Authored-By trailer naming Claude fails the gate"
expect_match 'carries a Co-Authored-By trailer naming Claude' "$gate_out" "the gate names the co-author rule"

# 9. A subject with a trailing period.
repo=$(new_repo feat/ship-naming)
add_commit "$repo" "feat(ship): standardise git naming."
gate "$repo"
expect_exit 1 "$gate_status" "a trailing period fails the gate"
expect_match 'subject ends with a period' "$gate_out" "the gate names the period rule"

# 10. No base branch to compare against.
repo=$(new_repo feat/ship-naming --no-base)
add_commit "$repo" "feat(ship): standardise git naming"
gate "$repo"
expect_exit 1 "$gate_status" "an unresolvable base fails the gate"
expect_match 'A gate that scanned nothing is not a pass' "$gate_out" "no base is the same failure as no commits"

# 11. Placeholders. A brace inside a diagram, a gherkin block or backticks is
# the convention being written down; a bare one in prose is an unfilled blank.
repo=$(new_repo feat/ship-naming)
cat >>"$repo/docs/specs/fixture.md" <<'DOCUMENTED'

```mermaid
flowchart LR
    A["/build"] --> H{{block-attribution.sh}}
```

```gherkin
Scenario: naming
  Then the subject matches "{type}({scope}): {subject}"
```

The branch is `{type}/{slice}`, and a spike is `spike/{question}`.
DOCUMENTED
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "docs(spec): document the format"
gate "$repo"
expect_exit 0 "$gate_status" "documented placeholders do not read as unfilled blanks"

repo=$(new_repo feat/ship-naming)
printf '\nThe branch is {slice} and the owner is {owner}.\n' >>"$repo/docs/specs/fixture.md"
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "docs(spec): leave a blank behind"
gate "$repo"
expect_exit 1 "$gate_status" "a bare placeholder in prose still fails the gate"
expect_match 'Placeholders left in the spec' "$gate_out" "the gate names the placeholder rule"

rm -rf "$work"
