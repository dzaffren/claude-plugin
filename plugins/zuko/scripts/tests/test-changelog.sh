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
