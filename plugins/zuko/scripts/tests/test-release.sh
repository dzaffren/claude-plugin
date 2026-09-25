# scripts/lib/release.py -- the release gates, the version rule and overrides,
# manifests, the changelog cut, the notes, and the resume states.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

work=$(mktemp -d -p "$work")
release="$scripts/lib/release.py"

# A stand-in for gh, first on PATH. It answers from files in $FAKE_GH and logs
# every call to $FAKE_GH/calls.
mkdir -p "$work/bin"
export FAKE_GH="$work/gh"
cat >"$work/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_GH/calls"
if [ -f "$FAKE_GH/api-error" ] && [ "$1" = api ]; then cat "$FAKE_GH/api-error" >&2; exit 1; fi
case "$1 $2" in
  "api "*/check-runs*) cat "$FAKE_GH/check-runs" ;;
  "api "*/status) cat "$FAKE_GH/status" ;;
  "release view")
    if [ -f "$FAKE_GH/view-error" ]; then cat "$FAKE_GH/view-error" >&2; exit 1; fi
    if [ -f "$FAKE_GH/released" ]; then printf 'title:\t%s\n' "$3"; exit 0; fi
    echo "release not found" >&2; exit 1 ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"

gh_reset() {   # gh_reset: no CI checks, no release, no errors
  rm -rf "$FAKE_GH"
  mkdir -p "$FAKE_GH"
  printf '{"total_count": 0, "check_runs": []}\n' >"$FAKE_GH/check-runs"
  printf '{"state": "pending", "total_count": 0, "statuses": []}\n' >"$FAKE_GH/status"
}

commit() {     # commit <repo> <message>: stage everything and commit, empty or not
  git -C "$1" add -A
  git -C "$1" commit -q --allow-empty --no-verify -m "$2"
}

overview() {   # overview <dir> <test cell>: an Active overview whose "Run it" test row holds <test cell>
  cat >"$1/OVERVIEW.md" <<OVERVIEW
# invoice-cli

**Status:** Active · **Updated:** 2026-09-25 by /ship export-csv

Turns a folder of supplier invoices into one ledger CSV.

## Run it

| Task    | Command            |
| ------- | ------------------ |
| install | \`pip install -e .\` |
| test    | $2 |
OVERVIEW
}

changelog() {  # changelog <dir>: two lines under [Unreleased] above a released 1.4.2
  cat >"$1/CHANGELOG.md" <<'LOG'
# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added

- Export the ledger as one CSV file.

### Fixed

- Invoice numbers keep their leading zeros.

## [1.4.2] - 2026-08-01

### Fixed

- Totals round to the cent.

[unreleased]: https://github.com/acme/invoice-cli/compare/v1.4.2...HEAD
[1.4.2]: https://github.com/acme/invoice-cli/compare/v1.4.1...v1.4.2
LOG
}

bare_repo() {  # bare_repo <dir>: fresh, no manifests, no tags, origin on GitHub
  git -C "$1" init -q -b main
  git -C "$1" config user.email t@example.com
  git -C "$1" config user.name Tester
  git -C "$1" remote add origin https://github.com/acme/invoice-cli.git
}

# The fixture every test starts from: invoice-cli on main, clean, tagged
# v1.4.2, then a fix and a feat, two lines under [Unreleased], no CI, and a
# test command that passes and leaves a mark outside the repo when it runs.
fixture() {    # fixture; prints the repo path
  local dir
  dir=$(mktemp -d -p "$work")
  bare_repo "$dir"
  overview "$dir" '`sh check.sh`'
  printf 'echo ran >>"%s.ran"\nexit 0\n' "$dir" >"$dir/check.sh"
  changelog "$dir"
  commit "$dir" "chore: start"
  git -C "$dir" tag v1.4.2
  commit "$dir" "fix(parsers): keep leading zeros"
  commit "$dir" "feat(exporters): write ledger csv"
  gh_reset
  printf '%s' "$dir"
}

run() {        # run <args...>; sets $out $status
  out=$(python3 "$release" "$@" 2>&1)
  status=$?
}

short() {      # short <repo>: HEAD's abbreviated sha
  git -C "$1" rev-parse --short HEAD
}

snapshot() {   # snapshot <repo>: every file's bytes, the status and the tags, as one hash
  { git -C "$1" status --porcelain; git -C "$1" tag; git -C "$1" rev-parse HEAD
    find "$1" -path "$1/.git" -prune -o -type f -print | sort | xargs cat; } | cksum
}

last_line() {  # last_line <text>
  printf '%s\n' "$1" | tail -n 1
}

# --- the gates ---

# 1. Every gate passing: the report names what each one looked at.
repo=$(fixture)
run plan "$repo"
sha=$(short "$repo")
expect_exit 0 "$status" "gates pass: exits 0"
expected="Release gates
  branch     main
  tree       clean
  remote     github.com/acme/invoice-cli
  tests      no CI checks on $sha — ran \"sh check.sh\": exit 0
  changelog  2 lines under [Unreleased]"
[ "$(printf '%s\n' "$out" | head -n 6)" = "$expected" ]
expect_exit 0 "$?" "gates pass: the report, line for line"
expect_match '^ran$' "$(cat "$repo.ran" 2>/dev/null)" "gates pass: the test command really ran"
expect_match 'api repos/acme/invoice-cli/commits/[0-9a-f]{40}/check-runs' "$(cat "$FAKE_GH/calls" 2>/dev/null)" "gates pass: asked GitHub for check runs on HEAD"
expect_match 'api repos/acme/invoice-cli/commits/[0-9a-f]{40}/status$' "$(cat "$FAKE_GH/calls" 2>/dev/null)" "gates pass: asked GitHub for commit statuses on HEAD"

# 2. On a feature branch.
repo=$(fixture)
git -C "$repo" checkout -q -b feat/export-csv
before=$(snapshot "$repo")
run plan "$repo"
expect_exit 1 "$status" "branch: exits 1"
expect_match '^Release gates FAILED$' "$out" "branch: the report says FAILED"
expect_match '^  branch     on feat/export-csv — release from main$' "$out" "branch: names the branch"
expect_match '^NEXT: stop$' "$(last_line "$out")" "branch: NEXT: stop"
expect_no_match '^Proposed' "$out" "branch: no version proposed"
expect_match "^$before\$" "$(snapshot "$repo")" "branch: nothing written or tagged"

# A near miss is still not main.
repo=$(fixture)
git -C "$repo" branch -q -m main-old
run plan "$repo"
expect_match '^  branch     on main-old — release from main$' "$out" "branch: main-old is not main"

# 3. Uncommitted changes, tracked and untracked.
repo=$(fixture)
echo "# note" >>"$repo/check.sh"
echo "draft" >"$repo/notes.txt"
before=$(snapshot "$repo")
run plan "$repo"
expect_exit 1 "$status" "tree: exits 1"
expect_match '^  tree       2 uncommitted files — commit or stash them first$' "$out" "tree: counts both files"
expect_match '^NEXT: stop$' "$(last_line "$out")" "tree: NEXT: stop"
expect_match "^$before\$" "$(snapshot "$repo")" "tree: nothing written"

# 4. The test command fails.
repo=$(fixture)
printf 'exit 1\n' >"$repo/check.sh"
commit "$repo" "test: break the check"
run plan "$repo"
expect_exit 1 "$status" "tests failing: exits 1"
expect_match '^  tests      "sh check\.sh" exited 1$' "$out" "tests failing: names the command and its exit"
expect_match '^NEXT: stop$' "$(last_line "$out")" "tests failing: NEXT: stop"

# 5. No CI and no test command: "not set up yet", no backticks, no overview.
for cell in 'not set up yet' 'run the suite'; do
  repo=$(fixture)
  overview "$repo" "$cell"
  commit "$repo" "docs: no test command"
  run plan "$repo"
  expect_exit 1 "$status" "no test command '$cell': exits 1"
  expect_match "^  tests      no CI checks on $(short "$repo") and no test command in OVERVIEW\\.md \"Run it\"\$" \
    "$out" "no test command '$cell': says neither exists"
done
repo=$(fixture)
git -C "$repo" rm -q OVERVIEW.md
commit "$repo" "docs: drop the overview"
run plan "$repo"
expect_match "^  tests      no CI checks on $(short "$repo") and no test command in OVERVIEW\\.md \"Run it\"\$" \
  "$out" "no overview: no test command"

# 6. CI checks on HEAD: two failing, one still running, the rest passing.
repo=$(fixture)
cat >"$FAKE_GH/check-runs" <<'JSON'
{"total_count": 4, "check_runs": [
  {"name": "unit", "status": "completed", "conclusion": "success"},
  {"name": "lint", "status": "completed", "conclusion": "failure"},
  {"name": "docs", "status": "completed", "conclusion": "skipped"},
  {"name": "e2e", "status": "in_progress", "conclusion": null}]}
JSON
run plan "$repo"
expect_exit 1 "$status" "CI failing: exits 1"
expect_match "^  tests      2 of 4 CI checks on $(short "$repo") failing: lint, e2e\$" "$out" "CI failing: names them; running is not passing"
expect_no_match '^ran$' "$(cat "$repo.ran" 2>/dev/null)" "CI failing: the local command did not run"

# Check runs and commit statuses both count; all green passes.
repo=$(fixture)
printf '{"total_count": 2, "check_runs": [{"name": "unit", "status": "completed", "conclusion": "success"}, {"name": "lint", "status": "completed", "conclusion": "neutral"}]}\n' >"$FAKE_GH/check-runs"
printf '{"state": "success", "total_count": 2, "statuses": [{"context": "ci/jenkins", "state": "success"}, {"context": "deploy", "state": "success"}]}\n' >"$FAKE_GH/status"
run plan "$repo"
expect_exit 0 "$status" "CI passing: exits 0"
expect_match "^  tests      4 CI checks on $(short "$repo"), all passing\$" "$out" "CI passing: counts runs and statuses"
expect_no_match '^ran$' "$(cat "$repo.ran" 2>/dev/null)" "CI passing: the local command did not run"

# A status that is pending or failed is not passing.
repo=$(fixture)
printf '{"state": "failure", "total_count": 2, "statuses": [{"context": "ci/jenkins", "state": "failure"}, {"context": "deploy", "state": "pending"}]}\n' >"$FAKE_GH/status"
run plan "$repo"
expect_match "^  tests      2 of 2 CI checks on $(short "$repo") failing: ci/jenkins, deploy\$" "$out" "CI statuses: failure and pending both named"

# A gh error is never "no CI".
repo=$(fixture)
echo "HTTP 401: Bad credentials (https://api.github.com/repos/acme/invoice-cli/commits)" >"$FAKE_GH/api-error"
run plan "$repo"
expect_exit 1 "$status" "gh error: exits 1"
expect_match "^  tests      could not read CI checks on $(short "$repo"): HTTP 401: Bad credentials" "$out" "gh error: quotes gh"
expect_no_match 'no CI checks' "$out" "gh error: not read as no CI"
expect_no_match '^ran$' "$(cat "$repo.ran" 2>/dev/null)" "gh error: the local command did not run"

# 7. The changelog: no lines, no heading, no file.
repo=$(fixture)
awk '/^## \[Unreleased\]$/ { print; skip = 1; next } /^## / { skip = 0; print ""; } !skip' \
  "$repo/CHANGELOG.md" >"$work/log" && mv "$work/log" "$repo/CHANGELOG.md"
commit "$repo" "docs: empty the changelog"
expect_match '^## \[Unreleased\]$' "$(cat "$repo/CHANGELOG.md")" "changelog empty: the fixture kept the heading"
run plan "$repo"
expect_exit 1 "$status" "changelog empty: exits 1"
expect_match '^  changelog  \[Unreleased\] has no lines — nothing to release$' "$out" "changelog empty: says so"

repo=$(fixture)
sed -i.bak 's/^## \[Unreleased\]$/## Upcoming/' "$repo/CHANGELOG.md" && rm "$repo/CHANGELOG.md.bak"
commit "$repo" "docs: rename the heading"
run plan "$repo"
expect_match '^  changelog  CHANGELOG\.md has no "## \[Unreleased\]" heading$' "$out" "changelog no heading: says so"

repo=$(fixture)
git -C "$repo" rm -q CHANGELOG.md
commit "$repo" "docs: drop the changelog"
run plan "$repo"
expect_match '^  changelog  CHANGELOG\.md missing — /ship creates it$' "$out" "changelog missing: says /ship creates it"

# 8. The remote: GitLab, another host, a near miss, no origin, and ssh GitHub.
for pair in "https://gitlab.com/acme/invoice-cli.git|origin is gitlab.com — GitLab releases come in slice 6" \
            "git@bitbucket.org:acme/invoice-cli.git|origin is bitbucket.org — /release supports GitHub only" \
            "https://github.com.example.org/acme/invoice-cli.git|origin is github.com.example.org — /release supports GitHub only"; do
  repo=$(fixture)
  git -C "$repo" remote set-url origin "${pair%%|*}"
  run plan "$repo"
  expect_exit 1 "$status" "remote ${pair%%|*}: exits 1"
  expect_match "^  remote     ${pair#*|}\$" "$out" "remote ${pair%%|*}: named"
  expect_no_match 'api repos' "$(cat "$FAKE_GH/calls" 2>/dev/null)" "remote ${pair%%|*}: GitHub not asked"
done
repo=$(fixture)
git -C "$repo" remote remove origin
run plan "$repo"
expect_match '^  remote     no origin remote — add the GitHub repo as origin$' "$out" "remote: none"
for url in git@github.com:acme/invoice-cli.git ssh://git@github.com/acme/invoice-cli http://github.com/acme/invoice-cli/; do
  repo=$(fixture)
  git -C "$repo" remote set-url origin "$url"
  run plan "$repo"
  expect_match '^  remote     github\.com/acme/invoice-cli$' "$out" "remote $url: read as github.com/acme/invoice-cli"
done

# 9. Every failing gate is listed, not just the first.
repo=$(fixture)
git -C "$repo" checkout -q -b feat/export-csv
git -C "$repo" rm -q CHANGELOG.md
echo "draft" >"$repo/notes.txt"
run plan "$repo"
expect_match '^  branch     on feat/export-csv' "$out" "several: branch listed"
expect_match '^  tree       2 uncommitted files' "$out" "several: tree listed"
expect_match '^  changelog  CHANGELOG\.md missing' "$out" "several: changelog listed"
expect_match '^NEXT: stop$' "$(last_line "$out")" "several: NEXT: stop"

# 10. Bad input is exit 2, not a gate result.
run plan "$work/nowhere"
expect_exit 2 "$status" "no dir: exits 2"
run plan
expect_exit 2 "$status" "no args: exits 2"
run plan "$(mktemp -d -p "$work")"
expect_exit 2 "$status" "not a git repo: exits 2"
expect_match 'not a git repository' "$out" "not a git repo: says so"
