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
  "api "*/check-runs*page=2*) cat "$FAKE_GH/check-runs-2" ;;
  "api "*/check-runs*) cat "$FAKE_GH/check-runs" ;;
  "api "*/status*) cat "$FAKE_GH/status" ;;
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
# Given a tag and subjects, it tags that and commits those instead.
fixture() {    # fixture [<tag> <subject>...]; prints the repo path
  local dir subject
  dir=$(mktemp -d -p "$work")
  bare_repo "$dir"
  overview "$dir" '`sh check.sh`'
  printf 'echo ran >>"%s.ran"\nexit 0\n' "$dir" >"$dir/check.sh"
  changelog "$dir"
  commit "$dir" "chore: start"
  git -C "$dir" tag "${1:-v1.4.2}"
  if [ $# -gt 1 ]; then
    shift
    for subject in "$@"; do commit "$dir" "$subject"; done
  else
    commit "$dir" "fix(parsers): keep leading zeros"
    commit "$dir" "feat(exporters): write ledger csv"
  fi
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
expect_match 'api repos/acme/invoice-cli/commits/[0-9a-f]{40}/status\?per_page=100&page=1$' "$(cat "$FAKE_GH/calls" 2>/dev/null)" "gates pass: asked GitHub for commit statuses on HEAD"

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

# 3b. A test command that leaves a file behind dirties the tree after its gate
# passed; plan must say so, or every cut after it refuses.
repo=$(fixture)
printf 'echo data >.coverage\nexit 0\n' >"$repo/check.sh"
commit "$repo" "chore: write coverage"
run plan "$repo"
expect_exit 1 "$status" "test leaves a file: exits 1"
expect_match '^  tree       1 uncommitted file — commit or stash them first$' "$out" "test leaves a file: the tree gate sees it"
expect_match '^NEXT: stop$' "$(last_line "$out")" "test leaves a file: NEXT: stop"

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

# 6b. More check runs than one page holds: a failure on page 2 still fails.
repo=$(fixture)
python3 - "$FAKE_GH" <<'PAGES'
import json, os, sys
run = lambda n, c: {"name": n, "status": "completed", "conclusion": c}
with open(os.path.join(sys.argv[1], "check-runs"), "w") as f:
    json.dump({"total_count": 101, "check_runs": [run("shard-%d" % i, "success") for i in range(1, 101)]}, f)
with open(os.path.join(sys.argv[1], "check-runs-2"), "w") as f:
    json.dump({"total_count": 101, "check_runs": [run("shard-101", "failure")]}, f)
PAGES
run plan "$repo"
expect_exit 1 "$status" "paged CI: exits 1"
expect_match '^  tests      1 of 101 CI checks on [0-9a-f]+ failing: shard-101$' "$out" "paged CI: reads page 2 and names its failure"

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

# --- the version rule ---

today=$(date +%F)
feat_break="feat(config)!: read settings from invoice.toml"

proposed() {   # proposed <text>: the Proposed line
  printf '%s\n' "$1" | grep '^Proposed'
}

# 11. A fix and a feat since v1.4.2: minor, and the whole plan.
repo=$(fixture)
run plan "$repo"
expect_exit 0 "$status" "rule feat: exits 0"
expected="
Last version  1.4.2  from tag v1.4.2
Since then    2 commits: 1 feat · 1 fix · 0 breaking
Proposed      1.5.0  — a feat since 1.4.2 bumps minor

Will write
  CHANGELOG.md   [Unreleased] → [1.5.0] - $today, links
  OVERVIEW.md    Release: v1.5.0 on the status line
Then
  commit \"chore(release): v1.5.0\" on main · annotated tag v1.5.0
  push main and v1.5.0 to origin · GitHub release v1.5.0

Release 1.5.0? Say yes, or give another version.
NEXT: ask 1.5.0"
[ "$(printf '%s\n' "$out" | tail -n +7)" = "$expected" ]
expect_exit 0 "$?" "rule feat: the plan and the question, line for line"

# 12. The rest of the table.
repo=$(fixture v1.4.2 "fix(parsers): keep leading zeros")
run plan "$repo"
expect_match '^Proposed      1\.4\.3  — a fix since 1\.4\.2 bumps patch$' "$(proposed "$out")" "rule fix: patch"
expect_match '^NEXT: ask 1\.4\.3$' "$(last_line "$out")" "rule fix: NEXT: ask 1.4.3"

repo=$(fixture v1.4.2 "fix(parsers): keep leading zeros" "feat(exporters): write ledger csv" "$feat_break")
run plan "$repo"
expect_match '^Since then    3 commits: 2 feat · 1 fix · 1 breaking$' "$out" "rule breaking: counted"
expect_match '^Proposed      2\.0\.0  — a breaking change since 1\.4\.2 bumps major$' "$(proposed "$out")" "rule breaking: major"
expect_match '^NEXT: ask 2\.0\.0$' "$(last_line "$out")" "rule breaking: NEXT: ask 2.0.0"

repo=$(fixture v0.3.1 "$feat_break")
run plan "$repo"
expect_match '^Proposed      0\.4\.0  — a breaking change on 0\.x bumps minor \(semver §4\)$' "$(proposed "$out")" "rule 0.x breaking: minor"

for footer in "BREAKING CHANGE" "BREAKING-CHANGE"; do
  repo=$(fixture v1.4.2 "$(printf 'refactor(config): load settings once\n\n%s: settings.ini is no longer read.' "$footer")")
  run plan "$repo"
  expect_match '^Proposed      2\.0\.0  — a breaking change since 1\.4\.2 bumps major$' "$(proposed "$out")" "rule footer '$footer': major"
done
repo=$(fixture v1.4.2 "chore!: drop python 3.8")
run plan "$repo"
expect_match '^Proposed      2\.0\.0 ' "$(proposed "$out")" "rule chore!: major"
repo=$(fixture v1.4.2 "feat(sc!ope): odd scope")
run plan "$repo"
expect_match '^Proposed      1\.5\.0 ' "$(proposed "$out")" "rule a ! inside the scope is not breaking"

# 13. Nothing calls for a release.
repo=$(fixture v1.4.2 "chore(deps): bump ruff" "docs: explain the exporter")
run plan "$repo"
expect_exit 0 "$status" "rule nothing: exits 0"
expect_match '^Nothing since 1\.4\.2 calls for a release: 2 commits, none feat, fix or breaking\.$' "$out" "rule nothing: says why"
expect_match '^\[Unreleased\] has 2 lines\. Give a version to release anyway, or stop here\.$' "$out" "rule nothing: names the lines"
expect_no_match '^Proposed' "$out" "rule nothing: proposes nothing"
expect_match '^NEXT: ask-version$' "$(last_line "$out")" "rule nothing: NEXT: ask-version"

# 14. The last version is the newest semver tag on HEAD's history, in semver
# order; pre-releases, other names and tags on other branches do not count.
repo=$(fixture v1.9.0 "feat: nine")
git -C "$repo" tag v1.10.0
commit "$repo" "fix: ten"
git -C "$repo" tag v2.0.0-rc.1
git -C "$repo" tag nightly
git -C "$repo" checkout -q -b side
commit "$repo" "feat: side"
git -C "$repo" tag v3.0.0
git -C "$repo" checkout -q main
run plan "$repo"
expect_match '^Last version  1\.10\.0  from tag v1\.10\.0$' "$out" "last tag: semver order, reachable only"
expect_match '^Proposed      1\.10\.1 ' "$(proposed "$out")" "last tag: one fix since v1.10.0"

# --- overrides ---

# 15. Refused: not a version, a pre-release, not above the last.
repo=$(fixture)
for pair in '1.4.2|"1.4.2" is not above 1.4.2.' \
            '1.4.1|"1.4.1" is not above 1.4.2.' \
            'banana|"banana" is not a version.' \
            '1.5.0-rc.1|"1.5.0-rc.1" is a pre-release; those are not supported yet.'; do
  before=$(snapshot "$repo")
  run plan "$repo" --version "${pair%%|*}"
  expect_exit 1 "$status" "override ${pair%%|*}: exits 1"
  expect_match '^Release gates$' "$out" "override ${pair%%|*}: the gates passed"
  [ "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" = "${pair#*|} Give a plain X.Y.Z above 1.4.2, or yes for 1.5.0." ]
  expect_exit 0 "$?" "override ${pair%%|*}: refused, naming the rule"
  expect_match '^NEXT: stop$' "$(last_line "$out")" "override ${pair%%|*}: NEXT: stop"
  expect_match "^$before\$" "$(snapshot "$repo")" "override ${pair%%|*}: nothing written"
done

# 16. Pushed back: a patch when a feat calls for a minor.
run plan "$repo" --version 1.4.3
expect_exit 0 "$status" "override 1.4.3: exits 0"
expect_match '^Proposed      1\.4\.3  — your version; the commits call for 1\.5\.0$' "$(proposed "$out")" "override 1.4.3: shown as the user's"
expect_match '^  CHANGELOG\.md   \[Unreleased\] → \[1\.4\.3\] - ' "$out" "override 1.4.3: the plan writes 1.4.3"
[ "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" = "1.4.3 is a patch, but a feat since 1.4.2 calls for a minor (1.5.0). Users read a patch as fixes only. Release 1.4.3 anyway? yes, or give another version." ]
expect_exit 0 "$?" "override 1.4.3: the advice"
expect_no_match '^Release 1\.4\.3\? Say yes' "$out" "override 1.4.3: the advice replaces the question"
expect_match '^NEXT: confirm 1\.4\.3$' "$(last_line "$out")" "override 1.4.3: NEXT: confirm 1.4.3"

# Matches the commits: asked plainly. A leading v is read as the version.
run plan "$repo" --version 1.5.0
expect_match '^NEXT: ask 1\.5\.0$' "$(last_line "$out")" "override 1.5.0: NEXT: ask"
expect_match '^Proposed      1\.5\.0  — a feat since 1\.4\.2 bumps minor$' "$(proposed "$out")" "override 1.5.0: same as computed"
run plan "$repo" --version v1.6.0
expect_match '^Proposed      1\.6\.0  — your version; the commits call for 1\.5\.0$' "$(proposed "$out")" "override v1.6.0: a minor, read without the v"
expect_match '^NEXT: ask 1\.6\.0$' "$(last_line "$out")" "override v1.6.0: NEXT: ask"

# A major with nothing breaking.
run plan "$repo" --version 3.0.0
[ "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" = "3.0.0 is a major, but nothing since 1.4.2 is marked breaking. Fine for a milestone; users may look for something they must change. Release 3.0.0? yes, or give another version." ]
expect_exit 0 "$?" "override 3.0.0: the milestone advice"
expect_match '^NEXT: confirm 3\.0\.0$' "$(last_line "$out")" "override 3.0.0: NEXT: confirm"

# Too small for a breaking change.
repo=$(fixture v1.4.2 "fix(parsers): keep leading zeros" "$feat_break")
run plan "$repo" --version 1.5.0
[ "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" = "1.5.0 is a minor, but \"$feat_break\" is breaking, which calls for 2.0.0. Users pinned to ^1 get it without warning. Release 1.5.0 anyway? yes, or give another version." ]
expect_exit 0 "$?" "override 1.5.0 over breaking: the advice"
expect_match '^NEXT: confirm 1\.5\.0$' "$(last_line "$out")" "override 1.5.0 over breaking: NEXT: confirm"

repo=$(fixture v0.3.1 "$feat_break")
run plan "$repo" --version 0.3.2
[ "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" = "0.3.2 is a patch, but \"$feat_break\" is breaking, which calls for 0.4.0. Users pinned to ^0.3 get it without warning. Release 0.3.2 anyway? yes, or give another version." ]
expect_exit 0 "$?" "override 0.3.2 over 0.x breaking: the advice pins ^0.3"
run plan "$repo" --version 1.0.0
expect_match '^NEXT: ask 1\.0\.0$' "$(last_line "$out")" "override 1.0.0 over 0.x breaking: a major is no smaller, asked plainly"

# A minor when only fixes call for a patch.
repo=$(fixture v1.4.2 "fix(parsers): keep leading zeros")
run plan "$repo" --version 1.5.0
[ "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" = "1.5.0 is a minor, but nothing since 1.4.2 is a feat; the fixes call for a patch (1.4.3). Users read a minor as new features. Release 1.5.0 anyway? yes, or give another version." ]
expect_exit 0 "$?" "override 1.5.0 over fixes: the advice"

# Nothing calls for a release, and the user names one.
repo=$(fixture v1.4.2 "chore(deps): bump ruff")
run plan "$repo" --version 1.4.3
expect_match '^Proposed      1\.4\.3  — your version; nothing since 1\.4\.2 calls for a release$' "$(proposed "$out")" "override with nothing called: shown"
expect_match '^NEXT: ask 1\.4\.3$' "$(last_line "$out")" "override with nothing called: NEXT: ask"
run plan "$repo" --version banana
expect_match '^"banana" is not a version\. Give a plain X\.Y\.Z above 1\.4\.2\.$' "$out" "override with nothing called: no yes offered"

# 17. A tag for the version already exists elsewhere: zuko never moves it.
repo=$(fixture)
git -C "$repo" checkout -q -b side
commit "$repo" "feat: side"
side=$(short "$repo")
git -C "$repo" tag -a v1.5.0 -m v1.5.0
git -C "$repo" checkout -q main
before=$(snapshot "$repo")
run plan "$repo"
expect_exit 1 "$status" "tag elsewhere: exits 1"
expect_match '^Release gates FAILED$' "$out" "tag elsewhere: FAILED"
expect_match "^  tag        v1\\.5\\.0 exists at $side, not HEAD — check it by hand; zuko never moves a tag\$" "$out" "tag elsewhere: names the tag and its commit"
expect_match '^NEXT: stop$' "$(last_line "$out")" "tag elsewhere: NEXT: stop"
expect_match "^$before\$" "$(snapshot "$repo")" "tag elsewhere: nothing written"
run plan "$repo" --version 1.6.0
expect_match '^NEXT: ask 1\.6\.0$' "$(last_line "$out")" "tag elsewhere: another version is free"

# --- a first release, and the manifests ---

# An untagged repo with every other gate passing and one feat.
untagged() {   # untagged; prints the repo path
  local dir
  dir=$(mktemp -d -p "$work")
  bare_repo "$dir"
  overview "$dir" '`true`'
  changelog "$dir"
  commit "$dir" "chore: start"
  commit "$dir" "feat(exporters): write ledger csv"
  gh_reset
  printf '%s' "$dir"
}

marketplace() {  # marketplace <dir> <version>: zuko's shape, one local plugin and one remote
  mkdir -p "$1/.claude-plugin" "$1/plugins/zuko/.claude-plugin"
  cat >"$1/.claude-plugin/marketplace.json" <<JSON
{
  "name": "dzafran-claude-plugins",
  "metadata": { "version": "$2" },
  "plugins": [
    {
      "name": "zuko",
      "source": "./plugins/zuko",
      "version": "$2",
      "tags": ["workflow", "spec"]
    },
    {
      "name": "elsewhere",
      "source": { "source": "github", "repo": "acme/elsewhere" },
      "version": "9.0.0"
    }
  ]
}
JSON
  cat >"$1/plugins/zuko/.claude-plugin/plugin.json" <<JSON
{
  "name": "zuko",
  "version": "$2",
  "keywords": ["workflow", "spec"]
}
JSON
}

package_json() {  # package_json <dir> <version>
  printf '{\n  "name": "invoice-cli",\n  "version": "%s",\n  "private": true\n}\n' "$2" >"$1/package.json"
}

pyproject() {  # pyproject <dir> <version>: [project] holds it; a [tool.poetry] version is a decoy
  printf '[build-system]\nrequires = ["hatchling"]\n\n[project]\nname = "invoice-cli"\nversion = "%s"\n\n[tool.poetry]\nversion = "9.9.9"\n' "$2" >"$1/pyproject.toml"
}

cargo() {      # cargo <dir> <version>: [package] holds it; the others are decoys
  printf '[package]\nname = "invoice-cli"\nversion = "%s"\nedition = "2021"\n\n[[bin]]\nname = "invoice"\nversion = "0.0.1"\n\n[dependencies]\nserde = { version = "1.0" }\n' "$2" >"$1/Cargo.toml"
}

# 18. No tags and no manifest version: ask for the first one.
repo=$(untagged)
run plan "$repo"
expect_exit 0 "$status" "first: exits 0"
expected="
No tags and no manifest version to start from.
First version: 0.1.0 (still changing) or 1.0.0 (stable)?
NEXT: ask-first"
[ "$(printf '%s\n' "$out" | tail -n +7)" = "$expected" ]
expect_exit 0 "$?" "first: asks 0.1.0 or 1.0.0, line for line"
expect_no_match '^Proposed' "$out" "first: proposes nothing itself"

run plan "$repo" --version 0.1.0
expect_match '^Last version  none — no tags and no manifest version$' "$out" "first 0.1.0: no last version"
expect_match '^Proposed      0\.1\.0  — the first release$' "$(proposed "$out")" "first 0.1.0: the user's"
expect_match '^NEXT: ask 0\.1\.0$' "$(last_line "$out")" "first 0.1.0: NEXT: ask"
run plan "$repo" --version banana
expect_match '^"banana" is not a version\. Give a plain X\.Y\.Z\.$' "$out" "first banana: refused"
expect_match '^NEXT: stop$' "$(last_line "$out")" "first banana: NEXT: stop"

# A package.json with no version, and a pyproject whose version comes from the
# tag, are not sources.
repo=$(untagged)
printf '{\n  "name": "ledger-tools",\n  "private": true\n}\n' >"$repo/package.json"
printf '[project]\nname = "ledger-tools"\ndynamic = [\n  "version",\n]\n' >"$repo/pyproject.toml"
commit "$repo" "chore: add manifests"
run plan "$repo"
expect_match '^NEXT: ask-first$' "$(last_line "$out")" "first: versionless manifests are not a start"

# 19. zuko's own shape: no tags, the marketplace entry and its plugin.json.
repo=$(untagged)
marketplace "$repo" 2.1.0
commit "$repo" "chore: add the marketplace"
run plan "$repo"
expect_exit 0 "$status" "zuko shape: exits 0"
expected="
Last version  2.1.0  from plugin.json and marketplace.json (no tags yet)
Since then    3 commits: 1 feat · 0 fix · 0 breaking
Proposed      2.2.0  — a feat since 2.1.0 bumps minor

Will write
  CHANGELOG.md                              [Unreleased] → [2.2.0] - $today, links
  .claude-plugin/marketplace.json           2.1.0 → 2.2.0
  plugins/zuko/.claude-plugin/plugin.json   2.1.0 → 2.2.0
  OVERVIEW.md                               Release: v2.2.0 on the status line
Then
  commit \"chore(release): v2.2.0\" on main · annotated tag v2.2.0
  push main and v2.2.0 to origin · GitHub release v2.2.0

Release 2.2.0? Say yes, or give another version.
NEXT: ask 2.2.0"
[ "$(printf '%s\n' "$out" | tail -n +7)" = "$expected" ]
expect_exit 0 "$?" "zuko shape: the plan, line for line"

# A local source that climbs out of the repo is not followed.
repo=$(untagged)
marketplace "$repo" 2.1.0
sed -i.bak 's|"./plugins/zuko"|"../outside"|' "$repo/.claude-plugin/marketplace.json" && rm "$repo/.claude-plugin/marketplace.json.bak"
mkdir -p "$(dirname "$repo")/outside/.claude-plugin"
printf '{ "version": "2.1.0" }\n' >"$(dirname "$repo")/outside/.claude-plugin/plugin.json"
commit "$repo" "chore: add the marketplace"
run plan "$repo"
expect_match '^  \.claude-plugin/marketplace\.json   2\.1\.0 → 2\.2\.0$' "$out" "outside source: the entry is still bumped"
expect_no_match 'outside' "$out" "outside source: the plugin.json outside the repo is not"

# 20. Manifests that disagree stop the release, naming every file and version.
repo=$(untagged)
package_json "$repo" 1.2.0
pyproject "$repo" 1.3.0
commit "$repo" "chore: add manifests"
before=$(snapshot "$repo")
run plan "$repo"
expect_exit 1 "$status" "disagree: exits 1"
expect_match '^  manifests  versions disagree: package\.json 1\.2\.0 · pyproject\.toml 1\.3\.0$' "$out" "disagree: both files, both versions"
expect_match '^NEXT: stop$' "$(last_line "$out")" "disagree: NEXT: stop"
expect_no_match 'First version' "$out" "disagree: no question asked"
expect_match "^$before\$" "$(snapshot "$repo")" "disagree: nothing written"

repo=$(untagged)
package_json "$repo" 1.0
commit "$repo" "chore: add package.json"
run plan "$repo"
expect_match '^  manifests  package\.json version "1\.0" is not a plain X\.Y\.Z$' "$out" "bad version: named"
repo=$(untagged)
printf '{ "version": "1.2.0", }\n' >"$repo/package.json"
commit "$repo" "chore: add package.json"
run plan "$repo"
expect_match '^  manifests  package\.json is not valid JSON$' "$out" "bad json: named"
repo=$(untagged)
printf '{ "version": "1.2\\u002e0" }\n' >"$repo/package.json"
commit "$repo" "chore: add package.json"
run plan "$repo"
expect_match '^  manifests  package\.json: cannot find its version to bump in place — bump it by hand$' "$out" "escaped version: not guessed at"

# A pyproject whose version comes from the tag is not touched, and says so.
repo=$(untagged)
package_json "$repo" 1.2.0
printf '[project]\nname = "invoice-cli"\ndynamic = ["version"]\n' >"$repo/pyproject.toml"
commit "$repo" "chore: add manifests"
run plan "$repo"
expect_match '^Last version  1\.2\.0  from package\.json \(no tags yet\)$' "$out" "dynamic: the last version is package.json's"
expect_match '^  pyproject\.toml: version comes from the tag, not touched$' "$out" "dynamic: says so"
expect_no_match '^  pyproject\.toml  ' "$out" "dynamic: not in the write list"

# 21. Every kind at once, with a tag: the tag is the last version, and every
# manifest is bumped from its own version.
repo=$(fixture)
package_json "$repo" 1.4.2
pyproject "$repo" 1.4.2
cargo "$repo" 1.4.2
mkdir -p "$repo/.claude-plugin"
printf '{ "name": "invoice-cli", "version": "1.4.2" }\n' >"$repo/.claude-plugin/plugin.json"
marketplace "$repo" 1.4.2
commit "$repo" "chore: add manifests"
run plan "$repo"
expect_match '^Last version  1\.4\.2  from tag v1\.4\.2$' "$out" "every kind: the tag wins"
expected="Will write
  CHANGELOG.md                              [Unreleased] → [1.5.0] - $today, links
  package.json                              1.4.2 → 1.5.0
  pyproject.toml                            1.4.2 → 1.5.0
  Cargo.toml                                1.4.2 → 1.5.0
  .claude-plugin/plugin.json                1.4.2 → 1.5.0
  .claude-plugin/marketplace.json           1.4.2 → 1.5.0
  plugins/zuko/.claude-plugin/plugin.json   1.4.2 → 1.5.0
  OVERVIEW.md                               Release: v1.5.0 on the status line"
[ "$(printf '%s\n' "$out" | sed -n '/^Will write$/,/^Then$/p' | sed '$d')" = "$expected" ]
expect_exit 0 "$?" "every kind: listed in order, decoys left out"

# --- cut and notes ---

same() {       # same <file> <file>; prints 0 when the bytes match
  cmp -s "$1" "$2"
  printf '%s' "$?"
}

changed() {    # changed <repo>: the paths git sees changed, one line
  git -C "$1" status --porcelain | awk '{ print $2 }' | sort | tr '\n' ' '
}

# 22. The feature release: [Unreleased] moves under 1.5.0, with compare links.
repo=$(fixture)
cp "$repo/OVERVIEW.md" "$work/overview-before"
run cut "$repo" --version 1.5.0 --date 2026-09-25
expect_exit 0 "$status" "cut: exits 0"
cat >"$work/expected" <<'LOG'
# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

## [1.5.0] - 2026-09-25

### Added

- Export the ledger as one CSV file.

### Fixed

- Invoice numbers keep their leading zeros.

## [1.4.2] - 2026-08-01

### Fixed

- Totals round to the cent.

[unreleased]: https://github.com/acme/invoice-cli/compare/v1.5.0...HEAD
[1.5.0]: https://github.com/acme/invoice-cli/compare/v1.4.2...v1.5.0
[1.4.2]: https://github.com/acme/invoice-cli/compare/v1.4.1...v1.4.2
LOG
expect_exit 0 "$(same "$repo/CHANGELOG.md" "$work/expected")" "cut: CHANGELOG.md byte for byte"
sed 's/^\*\*Status:\*\* Active · /**Status:** Active · **Release:** v1.5.0 · /' "$work/overview-before" >"$work/expected"
expect_exit 0 "$(same "$repo/OVERVIEW.md" "$work/expected")" "cut: the overview's status line gains the release, nothing else"
expect_match '^CHANGELOG\.md OVERVIEW\.md $' "$(changed "$repo")" "cut: writes only what the plan listed"
expected="Wrote
  CHANGELOG.md   [Unreleased] → [1.5.0] - 2026-09-25, links
  OVERVIEW.md    Release: v1.5.0 on the status line"
[ "$(printf '%s\n' "$out" | sed -n '/^Wrote$/,$p')" = "$expected" ]
expect_exit 0 "$?" "cut: says what it wrote"
expect_match '^Project overview \(OVERVIEW\.md\):$' \
  "$(CLAUDE_PROJECT_DIR="$repo" bash "$scripts/load-overview.sh" | head -n 1)" "cut: the session loader still reads the status as Active"
expect_no_match '^Proposed' "$(python3 "$release" plan "$repo" 2>&1)" "cut: a dirty tree after it, as the skill commits next"

# 23. notes: the lines under a version, exactly, without the heading.
run notes "$repo" --version 1.5.0
expect_exit 0 "$status" "notes: exits 0"
[ "$out" = "$(printf '### Added\n\n- Export the ledger as one CSV file.\n\n### Fixed\n\n- Invoice numbers keep their leading zeros.')" ]
expect_exit 0 "$?" "notes: the [1.5.0] lines, exactly"
python3 "$release" notes "$repo" --version 1.5.0 >"$work/notes"
expect_match '^- Invoice numbers keep their leading zeros\.$' "$(tail -c 200 "$work/notes")" "notes: ends on its last line"
expect_exit 0 "$(tail -c 1 "$work/notes" | od -An -c | tr -d ' ' | grep -qx '\\n'; printf '%s' $?)" "notes: with one newline after it"
run notes "$repo" --version 1.4.2
[ "$out" = "$(printf '### Fixed\n\n- Totals round to the cent.')" ]
expect_exit 0 "$?" "notes: the last section stops before the link definitions"
run notes "$repo" --version 9.9.9
expect_exit 1 "$status" "notes: no such version exits 1"
expect_match '^CHANGELOG\.md has no \[9\.9\.9\] section$' "$out" "notes: says which"
run notes "$repo" --version banana
expect_exit 2 "$status" "notes: not a version exits 2"

# 24. A first release from the manifests: the entry and its plugin.json bumped
# in place, the metadata and the remote plugin untouched, and the release page
# linked, since there is no tag to compare with.
repo=$(untagged)
marketplace "$repo" 2.1.0
printf '# Changelog\n\n## [Unreleased]\n\n### Added\n\n- Export the ledger as one CSV file.\n' >"$repo/CHANGELOG.md"
commit "$repo" "chore: add the marketplace"
run cut "$repo" --version 2.2.0 --date 2026-09-25
expect_exit 0 "$status" "cut first: exits 0"
printf '# Changelog\n\n## [Unreleased]\n\n## [2.2.0] - 2026-09-25\n\n### Added\n\n- Export the ledger as one CSV file.\n\n[unreleased]: https://github.com/acme/invoice-cli/compare/v2.2.0...HEAD\n[2.2.0]: https://github.com/acme/invoice-cli/releases/tag/v2.2.0\n' >"$work/expected"
expect_exit 0 "$(same "$repo/CHANGELOG.md" "$work/expected")" "cut first: links added at the bottom, the release page for 2.2.0"
mkdir -p "$work/zuko"
marketplace "$work/zuko" 2.2.0
sed 's/"metadata": { "version": "2.2.0" }/"metadata": { "version": "2.1.0" }/' "$work/zuko/.claude-plugin/marketplace.json" >"$work/expected"
expect_exit 0 "$(same "$repo/.claude-plugin/marketplace.json" "$work/expected")" "cut first: marketplace.json byte for byte"
expect_exit 0 "$(same "$repo/plugins/zuko/.claude-plugin/plugin.json" "$work/zuko/plugins/zuko/.claude-plugin/plugin.json")" "cut first: plugin.json byte for byte"
expect_match '^\.claude-plugin/marketplace\.json CHANGELOG\.md OVERVIEW\.md plugins/zuko/\.claude-plugin/plugin\.json $' \
  "$(changed "$repo")" "cut first: those files and no others"

# 25. Every kind at once: the version line, and not the decoys.
repo=$(fixture)
package_json "$repo" 1.4.2
pyproject "$repo" 1.4.2
cargo "$repo" 1.4.2
commit "$repo" "chore: add manifests"
run cut "$repo" --version 1.5.0 --date 2026-09-25
expect_exit 0 "$status" "cut every kind: exits 0"
mkdir -p "$work/kinds"
package_json "$work/kinds" 1.5.0
pyproject "$work/kinds" 1.5.0
cargo "$work/kinds" 1.5.0
for file in package.json pyproject.toml Cargo.toml; do
  expect_exit 0 "$(same "$repo/$file" "$work/kinds/$file")" "cut every kind: $file byte for byte"
done

# 26. An existing Release field is replaced, not repeated.
repo=$(fixture)
sed -i.bak 's/^\*\*Status:\*\* Active · /**Status:** Active · **Release:** v1.4.2 · /' "$repo/OVERVIEW.md" && rm "$repo/OVERVIEW.md.bak"
commit "$repo" "docs: record the last release"
run cut "$repo" --version 1.5.0 --date 2026-09-25
expect_match '^\*\*Status:\*\* Active · \*\*Release:\*\* v1\.5\.0 · \*\*Updated:\*\* 2026-09-25 by /ship export-csv$' \
  "$(cat "$repo/OVERVIEW.md")" "cut: the Release field replaced"

# 27. cut re-checks what plan checks, and writes nothing on any failure.
repo=$(fixture)
git -C "$repo" checkout -q -b feat/export-csv
before=$(snapshot "$repo")
run cut "$repo" --version 1.5.0 --date 2026-09-25
expect_exit 1 "$status" "cut on a branch: exits 1"
expect_match '^  branch     on feat/export-csv — release from main$' "$out" "cut on a branch: names the gate"
expect_match '^Nothing written\.$' "$(last_line "$out")" "cut on a branch: says nothing was written"
expect_match "^$before\$" "$(snapshot "$repo")" "cut on a branch: nothing written"

repo=$(fixture)
before=$(snapshot "$repo")
run cut "$repo" --version 1.4.2 --date 2026-09-25
expect_exit 1 "$status" "cut a refused version: exits 1"
expect_match '^"1\.4\.2" is not above 1\.4\.2\.' "$out" "cut a refused version: says why"
expect_match "^$before\$" "$(snapshot "$repo")" "cut a refused version: nothing written"

repo=$(untagged)
package_json "$repo" 1.2.0
pyproject "$repo" 1.3.0
commit "$repo" "chore: add manifests"
before=$(snapshot "$repo")
run cut "$repo" --version 1.4.0 --date 2026-09-25
expect_exit 1 "$status" "cut disagreeing manifests: exits 1"
expect_match "^$before\$" "$(snapshot "$repo")" "cut disagreeing manifests: nothing written"

# A file cut would write is read-only: nothing is written, not half of it.
repo=$(fixture)
package_json "$repo" 1.4.2
commit "$repo" "chore: add package.json"
chmod a-w "$repo/package.json"
before=$(snapshot "$repo")
run cut "$repo" --version 1.5.0 --date 2026-09-25
chmod u+w "$repo/package.json"
expect_exit 1 "$status" "cut a read-only manifest: exits 1"
expect_match '^Cannot write package\.json\.$' "$out" "cut a read-only manifest: names the file"
expect_match '^Nothing written\.$' "$(last_line "$out")" "cut a read-only manifest: says nothing was written"
expect_match "^$before\$" "$(snapshot "$repo")" "cut a read-only manifest: nothing written"

# A version the user confirmed despite the advice is cut.
repo=$(fixture)
run cut "$repo" --version 1.4.3 --date 2026-09-25
expect_exit 0 "$status" "cut a confirmed patch: exits 0"
expect_match '^## \[1\.4\.3\] - 2026-09-25$' "$(cat "$repo/CHANGELOG.md")" "cut a confirmed patch: written"

# 28. Bad input is exit 2, and writes nothing.
repo=$(fixture)
before=$(snapshot "$repo")
run cut "$repo" --version 1.5.0
expect_exit 2 "$status" "cut no date: exits 2"
run cut "$repo" --version 1.5.0 --date 25-09-2026
expect_exit 2 "$status" "cut bad date: exits 2"
run cut "$repo" --date 2026-09-25
expect_exit 2 "$status" "cut no version: exits 2"
expect_match "^$before\$" "$(snapshot "$repo")" "cut bad input: nothing written"

# --- resuming a release that stopped after the tag ---

pushes_to() {  # pushes_to <repo> <bare>: origin still reads github.com; pushes land in <bare>
  git -C "$1" config "url.$2.insteadOf" https://github.com/acme/invoice-cli.git
}

# The fixture released as far as the tag: cut, committed and tagged 1.5.0,
# with origin pushing to an empty bare repo.
tagged() {     # tagged; prints the repo path
  local dir bare
  dir=$(fixture)
  bare=$(mktemp -d -p "$work")
  git init -q --bare "$bare"
  pushes_to "$dir" "$bare"
  python3 "$release" cut "$dir" --version 1.5.0 --date 2026-09-25 >/dev/null
  commit "$dir" "chore(release): v1.5.0"
  git -C "$dir" tag -a v1.5.0 -m v1.5.0
  : >"$dir.ran"
  : >"$FAKE_GH/calls"
  printf '%s' "$dir"
}

gates_resumed="Release gates
  branch     main
  tree       clean
  remote     github.com/acme/invoice-cli
"

# 29. Tagged at HEAD, not on origin: push it, then create the release.
repo=$(tagged)
before=$(snapshot "$repo")
run plan "$repo"
expect_exit 0 "$status" "resume push: exits 0"
expected="${gates_resumed}
v1.5.0 is tagged at HEAD ($(short "$repo")) but not on origin.
Resuming: pushing main and v1.5.0, then creating the release from the [1.5.0] section. No new commit or tag.
NEXT: resume v1.5.0 push"
[ "$out" = "$expected" ]
expect_exit 0 "$?" "resume push: the report and the message, line for line"
expect_match '^$' "$(cat "$repo.ran")" "resume push: the tests are not run again"
expect_no_match 'api ' "$(cat "$FAKE_GH/calls")" "resume push: CI not asked again"
expect_match "^$before\$" "$(snapshot "$repo")" "resume push: nothing written or tagged"

# 30. On origin, and GitHub has no release: create it.
git -C "$repo" push -q origin main v1.5.0
run plan "$repo"
expect_exit 0 "$status" "resume release: exits 0"
expected="${gates_resumed}
v1.5.0 is tagged at HEAD ($(short "$repo")) and on origin, but GitHub has no release v1.5.0.
Resuming: creating the release from the [1.5.0] section. No new commit or tag.
NEXT: resume v1.5.0 release"
[ "$out" = "$expected" ]
expect_exit 0 "$?" "resume release: the spec's message, line for line"
expect_match '^release view v1\.5\.0 --repo acme/invoice-cli$' "$(cat "$FAKE_GH/calls")" "resume release: asked GitHub for that release"

# cut refuses to cut again.
before=$(snapshot "$repo")
run cut "$repo" --version 1.5.0 --date 2026-09-25
expect_exit 1 "$status" "resume cut: exits 1"
expect_match '^v1\.5\.0 is tagged at HEAD; resume the release instead of cutting again\.$' "$out" "resume cut: says why"
expect_match '^Nothing written\.$' "$(last_line "$out")" "resume cut: nothing written"
expect_match "^$before\$" "$(snapshot "$repo")" "resume cut: the files are untouched"

# 31. The release exists: nothing to resume, and nothing since it.
touch "$FAKE_GH/released"
run plan "$repo"
expect_exit 1 "$status" "released: exits 1"
expect_match '^  commits    no commits since v1\.5\.0$' "$out" "released: no commits since the tag"
expect_match '^  changelog  \[Unreleased\] has no lines — nothing to release$' "$out" "released: [Unreleased] is empty"
expect_match '^NEXT: stop$' "$(last_line "$out")" "released: NEXT: stop"

# 32. GitHub cannot be asked: fail with gh's message, never guess.
repo=$(tagged)
git -C "$repo" push -q origin main v1.5.0
echo "HTTP 401: Bad credentials" >"$FAKE_GH/view-error"
run plan "$repo"
expect_exit 1 "$status" "release view error: exits 1"
expect_match '^  release    could not check GitHub for release v1\.5\.0: HTTP 401: Bad credentials$' "$out" "release view error: quotes gh"
expect_match '^NEXT: stop$' "$(last_line "$out")" "release view error: NEXT: stop"

# Origin cannot be reached: fail, never read it as "not pushed".
repo=$(tagged)
bare=$(git -C "$repo" config --local --get-regexp '^url\..*\.insteadof$' | awk '{ print $1 }' | sed 's/^url\.//; s/\.insteadof$//')
mv "$bare" "$bare.gone"
run plan "$repo"
expect_exit 1 "$status" "origin unreachable: exits 1"
expect_match '^  remote     could not reach origin: ' "$out" "origin unreachable: says so"
expect_no_match 'Resuming' "$out" "origin unreachable: no resume"

# 33. Resuming still needs main and a clean tree.
repo=$(tagged)
git -C "$repo" checkout -q -b feat/export-csv
run plan "$repo"
expect_match '^  branch     on feat/export-csv — release from main$' "$out" "resume on a branch: the gate fails"
expect_match '^NEXT: stop$' "$(last_line "$out")" "resume on a branch: NEXT: stop"
