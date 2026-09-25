# One walk through the release slice: invoice-cli, tagged v1.4.2, gets a feat
# and a fix. plan proposes 1.5.0, cut writes the changelog and package.json,
# the commit, annotated tag and push land in origin, the notes reach the GitHub
# release, a rerun resumes at the release, and a branch stops. The commit, tag,
# push and gh release create are done here with plain git and gh, as the
# /release skill does them. Sourced by run.sh, which provides $scripts, $work
# and the expect_* helpers.

work=$(mktemp -d -p "$work")
release="$scripts/lib/release.py"
repo="$work/repo"
bare="$work/origin.git"

# A stand-in for gh, first on PATH: no CI checks, no release yet, and
# "release create" keeps a copy of the notes file it was given.
mkdir -p "$work/bin" "$work/gh"
export FAKE_GH="$work/gh"
cat >"$work/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_GH/calls"
case "$1 $2" in
  "api "*/check-runs*) echo '{"total_count": 0, "check_runs": []}' ;;
  "api "*/status*) echo '{"state": "pending", "total_count": 0, "statuses": []}' ;;
  "release view") echo "release not found" >&2; exit 1 ;;
  "release create")
    while [ $# -gt 0 ]; do
      [ "$1" = "-F" ] && cp "$2" "$FAKE_GH/notes"
      shift
    done ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"

# origin reads github.com, so the remote gate passes; pushes land in $bare.
git init -q --bare "$bare"
mkdir -p "$repo"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester
git -C "$repo" remote add origin https://github.com/acme/invoice-cli.git
git -C "$repo" config "url.$bare.insteadOf" https://github.com/acme/invoice-cli.git

commit() {      # commit <message>
  git -C "$repo" add -A
  git -C "$repo" commit -q --no-verify -m "$1"
}

# Adds lines to CHANGELOG.md right after an existing one. awk reads "\n" in
# the new text as a line break.
after() {       # after <existing line> <new lines>
  awk -v at="$1" -v add="$2" '{ print } $0 == at { print add }' "$repo/CHANGELOG.md" >"$work/CHANGELOG.md"
  mv "$work/CHANGELOG.md" "$repo/CHANGELOG.md"
}

cat >"$repo/OVERVIEW.md" <<'OVERVIEW'
# invoice-cli

**Status:** Active · **Updated:** 2026-09-25 by /ship export-csv

Turns a folder of supplier invoices into one ledger CSV.

## Run it

| Task    | Command            |
| ------- | ------------------ |
| install | `pip install -e .` |
| test    | `sh check.sh`      |
OVERVIEW
printf 'exit 0\n' >"$repo/check.sh"
printf '{\n  "name": "invoice-cli",\n  "version": "1.4.2",\n  "bin": { "invoice": "cli.js" }\n}\n' >"$repo/package.json"
cat >"$repo/CHANGELOG.md" <<'LOG'
# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

## [1.4.2] - 2026-08-01

### Fixed

- Totals round to the cent.

[unreleased]: https://github.com/acme/invoice-cli/compare/v1.4.2...HEAD
[1.4.2]: https://github.com/acme/invoice-cli/compare/v1.4.1...v1.4.2
LOG
commit "chore: release 1.4.2"
git -C "$repo" tag -a v1.4.2 -m v1.4.2
git -C "$repo" push -q --atomic origin main v1.4.2

# A feat and a fix since, each with its changelog line, as /ship writes them.
echo "ledger" >"$repo/exporters.js"
after "## [Unreleased]" "\n### Added\n\n- Export the ledger as one CSV file."
commit "feat(exporters): write ledger csv"
echo "zeros" >"$repo/parsers.js"
after "- Export the ledger as one CSV file." "\n### Fixed\n\n- Invoice numbers keep their leading zeros."
commit "fix(parsers): keep leading zeros"
git -C "$repo" push -q origin main

# 1. plan proposes 1.5.0.
plan_out=$(python3 "$release" plan "$repo" 2>&1)
expect_exit 0 "$?" "e2e: plan passes the gates"
expect_match '^  tests      no CI checks on [0-9a-f]+ — ran "sh check\.sh": exit 0$' "$plan_out" "e2e: no CI, so the overview's test command ran"
expect_match '^Proposed      1\.5\.0  — a feat since 1\.4\.2 bumps minor$' "$plan_out" "e2e: a feat since v1.4.2 proposes 1.5.0"
expect_match '^  package\.json   1\.4\.2 → 1\.5\.0$' "$plan_out" "e2e: the plan lists the manifest"
expect_match '^NEXT: ask 1\.5\.0$' "$(printf '%s\n' "$plan_out" | tail -n 1)" "e2e: NEXT: ask 1.5.0"

# 2. The user says yes: cut writes the changelog and package.json, byte for byte.
cut_out=$(python3 "$release" cut "$repo" --version 1.5.0 --date 2026-09-25 2>&1)
expect_exit 0 "$?" "e2e: cut writes"
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
cmp -s "$repo/CHANGELOG.md" "$work/expected"
expect_exit 0 "$?" "e2e: CHANGELOG.md cut byte for byte"
printf '{\n  "name": "invoice-cli",\n  "version": "1.5.0",\n  "bin": { "invoice": "cli.js" }\n}\n' >"$work/expected"
cmp -s "$repo/package.json" "$work/expected"
expect_exit 0 "$?" "e2e: package.json bumped byte for byte"
expect_match '^\*\*Status:\*\* Active · \*\*Release:\*\* v1\.5\.0 · ' "$(cat "$repo/OVERVIEW.md")" "e2e: the overview names the release"
expect_match '^  OVERVIEW\.md    Release: v1\.5\.0 on the status line$' "$cut_out" "e2e: cut says what it wrote"

# 3. Commit, annotated tag, one atomic push: origin holds both.
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "chore(release): v1.5.0" -m "Changes CHANGELOG.md, package.json and OVERVIEW.md."
git -C "$repo" tag -a v1.5.0 -m v1.5.0
git -C "$repo" push -q --atomic origin main v1.5.0
expect_exit 0 "$?" "e2e: the push succeeds"
expect_match '^chore\(release\): v1\.5\.0$' "$(git -C "$bare" log -1 --format=%s main)" "e2e: origin's main has the release commit"
expect_match '^tag$' "$(git -C "$bare" cat-file -t v1.5.0)" "e2e: origin has v1.5.0 as an annotated tag"
expect_match "^$(git -C "$repo" rev-parse HEAD)\$" "$(git -C "$bare" rev-parse 'v1.5.0^{commit}')" "e2e: the tag points at the release commit"

# 4. notes is the [1.5.0] section, and the release gets exactly that.
python3 "$release" notes "$repo" --version 1.5.0 >"$work/notes.md"
expect_exit 0 "$?" "e2e: notes prints the section"
printf '### Added\n\n- Export the ledger as one CSV file.\n\n### Fixed\n\n- Invoice numbers keep their leading zeros.\n' >"$work/expected"
cmp -s "$work/notes.md" "$work/expected"
expect_exit 0 "$?" "e2e: the notes are the lines under [1.5.0], exactly"
(cd "$repo" && gh release create v1.5.0 --verify-tag -t v1.5.0 -F "$work/notes.md")
cmp -s "$FAKE_GH/notes" "$work/expected"
expect_exit 0 "$?" "e2e: gh release create received those notes"

# 5. GitHub still has no release: a rerun resumes at the release.
rerun=$(python3 "$release" plan "$repo" 2>&1)
expect_exit 0 "$?" "e2e: the rerun passes the gates"
expect_match "^v1\\.5\\.0 is tagged at HEAD \\($(git -C "$repo" rev-parse --short HEAD)\\) and on origin, but GitHub has no release v1\\.5\\.0\\.\$" \
  "$rerun" "e2e: the rerun finds the tag at HEAD"
expect_match '^NEXT: resume v1\.5\.0 release$' "$(printf '%s\n' "$rerun" | tail -n 1)" "e2e: NEXT: resume v1.5.0 release"
expect_no_match '^Proposed' "$rerun" "e2e: the rerun proposes no new version"

# 6. From a branch, nothing runs.
git -C "$repo" checkout -q -b feat/export-pdf
branch_out=$(python3 "$release" plan "$repo" 2>&1)
expect_exit 1 "$?" "e2e: a branch fails the gates"
expect_match '^  branch     on feat/export-pdf — release from main$' "$branch_out" "e2e: the branch gate names it"
expect_match '^NEXT: stop$' "$(printf '%s\n' "$branch_out" | tail -n 1)" "e2e: NEXT: stop"
