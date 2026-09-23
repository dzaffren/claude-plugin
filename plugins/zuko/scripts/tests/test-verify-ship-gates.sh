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
  write_overview "$1" Active fixture
}

# An overview at <status> whose slices table has one row, for <slice>.
write_overview() {   # write_overview <repo> <status> <slice>
  cat >"$1/OVERVIEW.md" <<OVERVIEW
# Fixture

**Status:** $2 · **Updated:** 2026-09-24 by /ship $3

## Slices

| Slice | Status | What it does | Page |
| ----- | ------ | ------------ | ---- |
| $3 | Built | The slice under test | https://claude.ai/... |

## More

README.md
OVERVIEW
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
expect_match 'No base branch to compare against' "$gate_out" "no base is the same failure as no commits"

# 10b. origin/HEAD can point at a ref that is no longer there. main still is.
repo=$(new_repo feat/ship-naming)
add_commit "$repo" "Bad subject with no type"
stale_sha=$(sha_of "$repo")
git -C "$repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
gate "$repo"
expect_exit 1 "$gate_status" "a dangling origin/HEAD does not stop the scan"
expect_match "Naming: checked 1 commits on feat/ship-naming ahead of main\." "$gate_out" "the scan falls back to main and says so"
expect_match "$stale_sha  subject is not" "$gate_out" "the offending commit is still caught"

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
printf '\nThe owner is {owner}.\n' >>"$repo/docs/specs/fixture.md"
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "docs(spec): leave a blank behind"
gate "$repo"
expect_exit 1 "$gate_status" "a bare placeholder in prose still fails the gate"
expect_match 'Placeholders left in the spec' "$gate_out" "the gate names the placeholder rule"

repo=$(new_repo feat/ship-naming)
printf '\n```gherkin\n  Then it retries TODO times\n```\n' >>"$repo/docs/specs/fixture.md"
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "docs(spec): leave a TODO in a fence"
gate "$repo"
expect_exit 1 "$gate_status" "a TODO inside a fenced block still fails the gate"

# 12. The overview. The slice is the spec's basename, "fixture"; each case
# commits its overview so the tree stays clean and only this check talks.
commit_overview() {   # commit_overview <repo>
  git -C "$1" add -A
  git -C "$1" commit -q --no-verify -m "docs(overview): change the overview"
}

repo=$(new_repo feat/fixture)
add_commit "$repo" "feat(scripts): add the fixture"
gate "$repo"
expect_exit 0 "$gate_status" "an Active overview with the slice's row passes"
expect_match '^Overview: row for "fixture" found$' "$gate_out" "the gate prints the overview scope line"

repo=$(new_repo feat/fixture)
git -C "$repo" rm -q OVERVIEW.md
commit_overview "$repo"
gate "$repo"
expect_exit 1 "$gate_status" "a missing overview fails the gate"
expect_match '^- OVERVIEW\.md  not onboarded — run any writing stage first$' "$gate_out" "a missing overview says not onboarded"
expect_no_match 'Overview: row' "$gate_out" "a missing overview prints no scope line"

repo=$(new_repo feat/fixture)
write_overview "$repo" Draft fixture
commit_overview "$repo"
gate "$repo"
expect_exit 1 "$gate_status" "a Draft overview fails the gate"
expect_match '^- OVERVIEW\.md  overview still Draft — approve it before shipping$' "$gate_out" "a Draft overview says approve it first"

repo=$(new_repo feat/fixture)
write_overview "$repo" Active fixture
grep -v 'Status:' "$repo/OVERVIEW.md" >"$repo/OVERVIEW.tmp" && mv "$repo/OVERVIEW.tmp" "$repo/OVERVIEW.md"
commit_overview "$repo"
gate "$repo"
expect_exit 1 "$gate_status" "an overview with no Status line fails the gate"
expect_match '^- OVERVIEW\.md  has no Status line — approve the onboarding draft first$' "$gate_out" "no Status line is named"

repo=$(new_repo feat/fixture)
write_overview "$repo" Active other-slice
commit_overview "$repo"
gate "$repo"
expect_exit 1 "$gate_status" "an Active overview without the slice's row fails the gate"
expect_match '^- OVERVIEW\.md  slices table has no row for "fixture"$' "$gate_out" "the missing row names the slice"
expect_no_match 'Overview: row' "$gate_out" "a missing row prints no scope line"

repo=$(new_repo feat/fixture)
write_overview "$repo" Active fixture-v2
commit_overview "$repo"
gate "$repo"
expect_exit 1 "$gate_status" "a row for a near-miss slice does not count"
expect_match 'slices table has no row for "fixture"' "$gate_out" "the near miss still names the slice"

repo=$(new_repo feat/fixture)
write_overview "$repo" Active other-slice
cat >>"$repo/OVERVIEW.md" <<'ELSEWHERE'

## Where things are

| fixture | mentioned here, outside the slices table |

The fixture slice is mentioned in prose too.
ELSEWHERE
commit_overview "$repo"
gate "$repo"
expect_exit 1 "$gate_status" "the slice mentioned only outside ## Slices does not count"
expect_match 'slices table has no row for "fixture"' "$gate_out" "a mention elsewhere still names the slice"

# Only Active passes: any other status is named and fails.
repo=$(new_repo feat/fixture)
write_overview "$repo" draft fixture
commit_overview "$repo"
gate "$repo"
expect_exit 1 "$gate_status" "a lowercase draft status fails the gate"
expect_match "^- OVERVIEW\.md  status is 'draft', not Active — approve the onboarding draft first$" "$gate_out" "an unknown status is named"
expect_no_match 'Overview: row' "$gate_out" "an unknown status prints no scope line"

# A row inside a code fence is an example, not the table.
repo=$(new_repo feat/fixture)
write_overview "$repo" Active other-slice
cat >>"$repo/OVERVIEW.md" <<'FENCED'

## Format

```
## Slices
| fixture | Built |
```
FENCED
commit_overview "$repo"
gate "$repo"
expect_exit 1 "$gate_status" "a row only inside a code fence does not count"
expect_match 'slices table has no row for "fixture"' "$gate_out" "a fenced row still names the slice"

rm -rf "$work"
