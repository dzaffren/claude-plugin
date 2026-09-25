# scripts/lib/changelog.py -- creating the file from tags, adding [Unreleased]
# to an existing one, and every outcome of the ship-gate check.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

work=$(mktemp -d -p "$work")
changelog="$scripts/lib/changelog.py"

new_repo() {   # new_repo; prints a fresh repo with one commit on main
  local dir
  dir=$(mktemp -d -p "$work")
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email t@example.com
  git -C "$dir" config user.name Tester
  git -C "$dir" commit -q --allow-empty --no-verify -m "chore: start"
  printf '%s' "$dir"
}

commit_on() {  # commit_on <repo> <YYYY-MM-DD> <subject>: an empty commit dated that day
  GIT_AUTHOR_DATE="$2T12:00:00+0000" GIT_COMMITTER_DATE="$2T12:00:00+0000" \
    git -C "$1" commit -q --allow-empty --no-verify -m "$3"
}

run() {        # run <args...>; sets $out $status
  out=$(python3 "$changelog" "$@" 2>&1)
  status=$?
}

same() {       # same <file> <file>; prints 0 when the bytes match
  cmp -s "$1" "$2"
  printf '%s' "$?"
}

header() {     # header <file>: what init writes before the first version
  cat >"$1" <<'HEAD'
# Changelog

All notable changes to this project are documented in this file. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
HEAD
}

past() {       # past <file> <version> <date>: a tag-seeded version heading
  printf '\n## [%s] - %s\n\nReleased before this changelog was kept.\n' "$2" "$3" >>"$1"
}

# --- init: a new file seeded from the repo's tags ---

# 1. No tags: the header and an empty [Unreleased], nothing else.
repo=$(new_repo)
run init "$repo"
expect_exit 0 "$status" "init no tags: exits 0"
expect_match '^CHANGELOG\.md: created with \[Unreleased\] and no past versions$' "$out" "init no tags: says so"
header "$work/expected"
expect_exit 0 "$(same "$repo/CHANGELOG.md" "$work/expected")" "init no tags: header and [Unreleased] only"

# 2. Not a git repo reads as no tags.
dir=$(mktemp -d -p "$work")
run init "$dir"
expect_exit 0 "$status" "init no git: exits 0"
expect_match '^CHANGELOG\.md: created with \[Unreleased\] and no past versions$' "$out" "init no git: no past versions"
expect_exit 0 "$(same "$dir/CHANGELOG.md" "$work/expected")" "init no git: header and [Unreleased] only"

# 3. One tag: singular.
repo=$(new_repo)
commit_on "$repo" 2025-03-02 "feat: first release"
git -C "$repo" tag v0.1.0
run init "$repo"
expect_exit 0 "$status" "init one tag: exits 0"
expect_match '^CHANGELOG\.md: created with \[Unreleased\] and 1 past version from tags \(v0\.1\.0\)$' \
  "$out" "init one tag: 1 past version"
header "$work/expected"; past "$work/expected" 0.1.0 2025-03-02
expect_exit 0 "$(same "$repo/CHANGELOG.md" "$work/expected")" "init one tag: the file as written"

# 4. Two tags and a non-semver one, as in invoice-cli.
repo=$(new_repo)
commit_on "$repo" 2025-03-02 "feat: first release"
git -C "$repo" tag v0.1.0
commit_on "$repo" 2025-04-10 "feat: monthly build"
git -C "$repo" tag release-2025-05
commit_on "$repo" 2025-05-19 "feat: second release"
git -C "$repo" tag v0.2.0
run init "$repo"
expect_exit 0 "$status" "init two tags: exits 0"
expect_match '^CHANGELOG\.md: created with \[Unreleased\] and 2 past versions from tags \(v0\.2\.0, v0\.1\.0\)$' \
  "$out" "init two tags: names them newest first"
expect_match '^Skipped tags that are not semver: release-2025-05$' "$out" "init two tags: names the skipped tag"
header "$work/expected"
past "$work/expected" 0.2.0 2025-05-19
past "$work/expected" 0.1.0 2025-03-02
expect_exit 0 "$(same "$repo/CHANGELOG.md" "$work/expected")" "init two tags: headings newest first, dated by tag"
expect_no_match '^### |^- ' "$(cat "$repo/CHANGELOG.md")" "init two tags: no feature lines invented"
expect_no_match 'release-2025-05' "$(cat "$repo/CHANGELOG.md")" "init two tags: the skipped tag gets no heading"

# 5. Semver order, a pre-release, a tag with no v, and an annotated tag's own date.
repo=$(new_repo)
commit_on "$repo" 2025-01-05 "feat: nine"
git -C "$repo" tag v0.9.0
commit_on "$repo" 2025-02-05 "feat: ten"
git -C "$repo" tag v0.10.0
commit_on "$repo" 2025-06-20 "feat: candidate"
git -C "$repo" tag v1.0.0-rc.1
GIT_COMMITTER_DATE="2025-07-01T12:00:00+0000" git -C "$repo" tag -a v1.0.0 -m "one"
commit_on "$repo" 2025-08-09 "feat: two"
git -C "$repo" tag 2.0.0
git -C "$repo" tag nightly
run init "$repo"
expect_exit 0 "$status" "init order: exits 0"
expect_match '^CHANGELOG\.md: created with \[Unreleased\] and 5 past versions from tags \(2\.0\.0, v1\.0\.0, v1\.0\.0-rc\.1, v0\.10\.0, v0\.9\.0\)$' \
  "$out" "init order: semver precedence, not string order"
expect_match '^Skipped tags that are not semver: nightly$' "$out" "init order: nightly skipped"
header "$work/expected"
past "$work/expected" 2.0.0 2025-08-09
past "$work/expected" 1.0.0 2025-07-01
past "$work/expected" 1.0.0-rc.1 2025-06-20
past "$work/expected" 0.10.0 2025-02-05
past "$work/expected" 0.9.0 2025-01-05
expect_exit 0 "$(same "$repo/CHANGELOG.md" "$work/expected")" "init order: annotated tag dated by the tagger, v dropped"

# 6. A file that exists is never overwritten.
repo=$(new_repo)
printf '# History\n\n## v3.4 (June 2025)\n' >"$repo/CHANGELOG.md"
cp "$repo/CHANGELOG.md" "$work/before"
run init "$repo"
expect_exit 1 "$status" "init exists: exits 1"
expect_match '^CHANGELOG\.md already exists — use add-unreleased$' "$out" "init exists: says to use add-unreleased"
expect_exit 0 "$(same "$repo/CHANGELOG.md" "$work/before")" "init exists: file untouched"

# 7. A project dir that does not exist.
run init "$work/nowhere"
expect_exit 2 "$status" "init no dir: exits 2"

# --- add-unreleased: an existing file in another shape ---

legacy() {     # legacy <dir>: legacy-api's changelog, newest heading on line 5
  cat >"$1/CHANGELOG.md" <<'OLD'
# Changelog for legacy-api

Everything notable, newest first.

## v3.4 (June 2025)

- Faster login.

## v3.3 (May 2025)

- Fixed a crash on empty input.
OLD
}

# 8. Without --write: the proposal only, file untouched.
dir=$(mktemp -d -p "$work"); legacy "$dir"; cp "$dir/CHANGELOG.md" "$work/before"
run add-unreleased "$dir"
expect_exit 0 "$status" "add proposal: exits 0"
expect_match '^CHANGELOG\.md exists without \[Unreleased\]\. Proposed change:$' "$out" "add proposal: first line"
expect_match '^  \+ ## \[Unreleased\]   \(above line 5, "v3\.4 \(June 2025\)"\)$' "$out" "add proposal: names line 5 and its heading"
expect_match '^2$' "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "add proposal: two lines, the approval prose is the skill's"
expect_exit 0 "$(same "$dir/CHANGELOG.md" "$work/before")" "add proposal: file untouched"

# 9. --write: the heading lands above line 5 and nothing else changes.
run add-unreleased "$dir" --write
expect_exit 0 "$status" "add write: exits 0"
expect_match '^CHANGELOG\.md: added \[Unreleased\] above line 5$' "$out" "add write: says where"
expect_match '^## \[Unreleased\]$' "$(sed -n 5p "$dir/CHANGELOG.md")" "add write: line 5 is the new heading"
expect_match '^$' "$(sed -n 6p "$dir/CHANGELOG.md")" "add write: one blank line after it"
expect_match '^## v3\.4 \(June 2025\)$' "$(sed -n 7p "$dir/CHANGELOG.md")" "add write: the old heading follows"
sed '5,6d' "$dir/CHANGELOG.md" >"$work/after-minus-new"
expect_exit 0 "$(same "$work/after-minus-new" "$work/before")" "add write: every other byte unchanged"

# 10. Already there: nothing to do.
cp "$dir/CHANGELOG.md" "$work/before"
run add-unreleased "$dir" --write
expect_exit 0 "$status" "add present: exits 0"
expect_match '^CHANGELOG\.md already has \[Unreleased\]$' "$out" "add present: says so"
expect_exit 0 "$(same "$dir/CHANGELOG.md" "$work/before")" "add present: file untouched"

# 11. No "## " heading at all: appended at the end.
dir=$(mktemp -d -p "$work")
printf '# Changelog\n\nNothing released yet.\n' >"$dir/CHANGELOG.md"
cp "$dir/CHANGELOG.md" "$work/before"
run add-unreleased "$dir"
expect_match '^  \+ ## \[Unreleased\]   \(at the end of the file\)$' "$out" "add append: proposal says at the end"
expect_exit 0 "$(same "$dir/CHANGELOG.md" "$work/before")" "add append: proposal leaves the file"
run add-unreleased "$dir" --write
expect_exit 0 "$status" "add append: exits 0"
expect_match '^CHANGELOG\.md: added \[Unreleased\] at the end of the file$' "$out" "add append: says where"
{ cat "$work/before"; printf '\n## [Unreleased]\n'; } >"$work/expected"
expect_exit 0 "$(same "$dir/CHANGELOG.md" "$work/expected")" "add append: after a blank line, nothing else changed"

# 12. Headings inside a code fence are examples, not headings.
dir=$(mktemp -d -p "$work")
cat >"$dir/CHANGELOG.md" <<'OLD'
# Changelog

```
## [Unreleased]
## 9.9 (example)
```

## 2.0 (2024)

- Rewrote the parser.
OLD
run add-unreleased "$dir"
expect_match '^  \+ ## \[Unreleased\]   \(above line 8, "2\.0 \(2024\)"\)$' "$out" "add fence: fenced headings skipped"

# 13. No file to add to.
dir=$(mktemp -d -p "$work")
run add-unreleased "$dir"
expect_exit 2 "$status" "add no file: exits 2"

# --- check: the ship gate's question ---

commit() {     # commit <repo> <message>: stage everything and commit, empty or not
  git -C "$1" add -A
  git -C "$1" commit -q --allow-empty --no-verify -m "$2"
}

gate_repo() {  # gate_repo; prints a repo on feat/export-csv whose base has one line under [Unreleased]
  local dir
  dir=$(new_repo)
  header "$dir/CHANGELOG.md"
  printf '\n### Added\n\n- Import invoices from a folder.\n' >>"$dir/CHANGELOG.md"
  past "$dir/CHANGELOG.md" 0.1.0 2025-03-02
  commit "$dir" "docs: start the changelog"
  git -C "$dir" checkout -q -b feat/export-csv
  printf '%s' "$dir"
}

# Rewrite <file> through an awk program, in place.
rewrite() {    # rewrite <file> <awk program>
  awk "$2" "$1" >"$1.tmp" && mv "$1.tmp" "$1"
}

add_line() {   # add_line <repo> <bullet>: a new line under Added, below the existing one
  rewrite "$1/CHANGELOG.md" "{ print } /^- Import invoices from a folder\\.\$/ { print \"$2\" }"
}

check() {      # check <repo>; sets $out $status
  out=$(python3 "$changelog" check "$1" --base "$(git -C "$1" merge-base HEAD main)" --label main 2>&1)
  status=$?
}

short() {      # short <repo> <rev>: the abbreviated sha git log prints
  git -C "$1" log -1 --format=%h "$2"
}

# 14. No file: fails whatever the commits are.
repo=$(new_repo); git -C "$repo" checkout -q -b chore/deps
commit "$repo" "chore(deps): bump ruff"
check "$repo"
expect_exit 1 "$status" "check missing: fails"
expect_match '^CHANGELOG\.md  missing — /ship creates it$' "$out" "check missing: says /ship creates it"

# 15. A file with no [Unreleased] heading: fails whatever the commits are.
repo=$(gate_repo)
rewrite "$repo/CHANGELOG.md" '!/^## \[Unreleased\]$/'
commit "$repo" "chore(deps): bump ruff"
check "$repo"
expect_exit 1 "$status" "check no heading: fails"
expect_match '^CHANGELOG\.md  has no "## \[Unreleased\]" heading$' "$out" "check no heading: says so"

# 16. A feat commit and no new line: fails, naming the commits that need one.
repo=$(gate_repo)
commit "$repo" "feat(exporters): write ledger csv"
commit "$repo" "chore(deps): bump ruff"
check "$repo"
expect_exit 1 "$status" "check no line: fails"
expect_match '^CHANGELOG\.md  no new line under \[Unreleased\] — this branch has feat or fix commits:$' \
  "$out" "check no line: the problem line"
expect_match "^                $(short "$repo" HEAD~1) feat\\(exporters\\): write ledger csv\$" \
  "$out" "check no line: names the sha and subject"
expect_no_match 'bump ruff' "$out" "check no line: the chore commit is not listed"
expect_no_match '^[^ ]' "$(printf '%s\n' "$out" | grep -v '^CHANGELOG\.md  ')" \
  "check no line: every other line is an indented continuation"

# 17. feat and fix commits with new lines: passes with the count.
repo=$(gate_repo)
commit "$repo" "feat(exporters): write ledger csv"
commit "$repo" "fix: keep leading zeros in invoice numbers"
commit "$repo" "chore(deps): bump ruff"
add_line "$repo" "- Export the ledger as one CSV file."
printf '\n### Fixed\n\n- Invoice numbers keep their leading zeros.\n' >"$work/fixed"
rewrite "$repo/CHANGELOG.md" "/^## \\[0\\.1\\.0\\]/ { while ((getline l < \"$work/fixed\") > 0) print l; print \"\" } { print }"
check "$repo"
expect_exit 0 "$status" "check lines: passes"
expect_match '^Changelog: 2 new lines under \[Unreleased\] for 2 feat/fix commits$' "$out" "check lines: counts lines and commits"

# One of each: singular.
repo=$(gate_repo)
commit "$repo" "feat(exporters): write ledger csv"
add_line "$repo" "- Export the ledger as one CSV file."
check "$repo"
expect_exit 0 "$status" "check one line: passes"
expect_match '^Changelog: 1 new line under \[Unreleased\] for 1 feat/fix commit$' "$out" "check one line: singular"

# 18. Only chores: no line needed.
repo=$(gate_repo)
commit "$repo" "chore(deps): bump ruff"
commit "$repo" "docs: explain the exporter"
check "$repo"
expect_exit 0 "$status" "check chores: passes"
expect_match '^Changelog: no feat or fix commits — no line needed$' "$out" "check chores: says no line needed"

# 19-21. Breaking changes need a line, whatever their type.
for subject in "feat(config)!: read settings from invoice.toml" "chore!: drop python 3.8"; do
  repo=$(gate_repo)
  commit "$repo" "$subject"
  check "$repo"
  expect_exit 1 "$status" "check breaking '$subject': fails"
  expect_match "^                $(short "$repo" HEAD) ${subject//[()]/.}\$" "$out" "check breaking '$subject': listed"
done
for footer in "BREAKING CHANGE" "BREAKING-CHANGE"; do
  repo=$(gate_repo)
  commit "$repo" "$(printf 'refactor(config): load settings once\n\n%s: settings.ini is no longer read.' "$footer")"
  check "$repo"
  expect_exit 1 "$status" "check footer '$footer': fails"
  expect_match "^                $(short "$repo" HEAD) refactor\\(config\\): load settings once\$" "$out" "check footer '$footer': listed"
done

# 22. Moving an existing line is not a new line.
repo=$(gate_repo)
commit "$repo" "feat(exporters): write ledger csv"
rewrite "$repo/CHANGELOG.md" '/^- Import invoices from a folder\.$/ { next } /^## \[0\.1\.0\]/ { print "### Changed"; print ""; print "- Import invoices from a folder."; print "" } { print }'
expect_match '^### Changed$' "$(cat "$repo/CHANGELOG.md")" "check moved: the fixture moved the line"
check "$repo"
expect_exit 1 "$status" "check moved: fails"

# 23. Rewording an existing line is a new line.
repo=$(gate_repo)
commit "$repo" "feat(importers): read zip files"
rewrite "$repo/CHANGELOG.md" '{ sub(/^- Import invoices from a folder\.$/, "- Import invoices from a folder or a zip file."); print }'
check "$repo"
expect_exit 0 "$status" "check reworded: passes"
expect_match '^Changelog: 1 new line under \[Unreleased\] for 1 feat/fix commit$' "$out" "check reworded: counted"

# 24. A line under an old version is not under [Unreleased].
repo=$(gate_repo)
commit "$repo" "feat(exporters): write ledger csv"
printf '\n- Export the ledger as one CSV file.\n' >>"$repo/CHANGELOG.md"
check "$repo"
expect_exit 1 "$status" "check old section: a line under 0.1.0 does not count"

# 25. The base has no changelog: every line under [Unreleased] is new.
repo=$(new_repo); git -C "$repo" checkout -q -b feat/export-csv
header "$repo/CHANGELOG.md"
printf '\n### Added\n\n- Export the ledger as one CSV file.\n' >>"$repo/CHANGELOG.md"
commit "$repo" "feat(exporters): write ledger csv"
check "$repo"
expect_exit 0 "$status" "check no base file: passes"
expect_match '^Changelog: 1 new line under \[Unreleased\] for 1 feat/fix commit$' "$out" "check no base file: every line is new"

# 26. Bad input is exit 2, not a gate result.
repo=$(gate_repo)
run check "$repo" --base no-such-commit
expect_exit 2 "$status" "check bad base: exits 2"
expect_match 'no-such-commit' "$out" "check bad base: names it"
run check "$repo"
expect_exit 2 "$status" "check no --base: exits 2"
run check "$work/nowhere" --base HEAD
expect_exit 2 "$status" "check no dir: exits 2"

# --- init: tag names git would print ambiguously ---

# 27. A branch with a tag's name: git shortens the tag to tags/v0.1.0, which
# is still the v0.1.0 release.
repo=$(new_repo)
git -C "$repo" tag v0.1.0
git -C "$repo" branch v0.1.0
run init "$repo"
expect_exit 0 "$status" "init tag and branch share a name: exits 0"
expect_match '^## \[0\.1\.0\] - ' "$(cat "$repo/CHANGELOG.md")" "init tag and branch share a name: the version is seeded"
expect_no_match 'Skipped|tags/' "$out" "init tag and branch share a name: nothing skipped"

# 28. Two tags for one version, with and without the v: one heading.
repo=$(new_repo)
git -C "$repo" tag v1.0.0
git -C "$repo" tag 1.0.0
run init "$repo"
expect_exit 0 "$status" "init v1.0.0 and 1.0.0: exits 0"
expect_match '^1$' "$(grep -c '^## \[1\.0\.0\]' "$repo/CHANGELOG.md")" "init v1.0.0 and 1.0.0: one heading"
expect_match 'and 1 past version from tags \(v1\.0\.0, 1\.0\.0\)$' "$out" "init v1.0.0 and 1.0.0: one version, both tags named"
