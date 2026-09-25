# One walk through the changelog slice: onboarding seeds CHANGELOG.md from the
# repo's tags, then the ship gate holds a feat branch to a line under
# [Unreleased], refuses an attributed line, lets a chore branch through with
# none, and accepts a breaking-change subject. Sourced by run.sh, which
# provides $scripts and the expect_* helpers.

work=$(mktemp -d -p "$work")
repo="$work/repo"
mkdir -p "$repo/docs/specs"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester

# Two releases from before the changelog, tagged on the day they shipped.
release() {     # release <tag> <date>
  echo "$1" >>"$repo/VERSION"
  git -C "$repo" add -A
  GIT_AUTHOR_DATE="$2T12:00:00+0000" GIT_COMMITTER_DATE="$2T12:00:00+0000" \
    git -C "$repo" commit -q --no-verify -m "chore: release $1"
  git -C "$repo" tag "$1"
}
release v0.1.0 2025-03-02
release v0.2.0 2025-05-19

# A spec, overview, decisions log and README that clear every other gate, so
# each failure below is the changelog.
cat >"$repo/docs/specs/export-csv.md" <<'SPEC'
# Export CSV

| | |
| --- | --- |
| **Rollout** | No flag. Revert the merge commit. |
| **Proof it works** | The gate prints the changelog scope line. |

**E2E:** this file.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
| O1 | Nothing is unresolved. | question | e2e | user | Resolved | Yes. |
SPEC
cat >"$repo/OVERVIEW.md" <<'OVERVIEW'
# invoice-cli

**Status:** Active · **Updated:** 2026-09-25 by /spec export-csv

Turns a folder of supplier invoices into one ledger CSV.

## Run it

| Task    | Command            |
| ------- | ------------------ |
| install | `pip install -e .` |

## Slices

| Slice      | Status | What it does                 | Page                  |
| ---------- | ------ | ---------------------------- | --------------------- |
| export-csv | Built  | Export the ledger as one CSV | https://claude.ai/... |
OVERVIEW
cat >"$repo/DECISIONS.md" <<'DECISIONS'
# Decisions

Append-only. A changed decision is a new entry that supersedes the old one; only an
old entry's Status line ever changes.
DECISIONS

# 1. Onboarding creates the changelog from the tags.
init_out=$(python3 "$scripts/lib/changelog.py" init "$repo" 2>&1)
expect_exit 0 "$?" "e2e: init creates the changelog"
expect_match '^CHANGELOG\.md: created with \[Unreleased\] and 2 past versions from tags \(v0\.2\.0, v0\.1\.0\)$' \
  "$init_out" "e2e: init names the tags it seeded from"
[ "$(grep '^## ' "$repo/CHANGELOG.md")" = "$(printf '## [Unreleased]\n## [0.2.0] - 2025-05-19\n## [0.1.0] - 2025-03-02')" ]
expect_exit 0 "$?" "e2e: [Unreleased], then both versions newest first with their tag dates"
expect_match '^Released before this changelog was kept\.$' "$(cat "$repo/CHANGELOG.md")" "e2e: past versions say only that"

# The README block links CHANGELOG.md, so it renders after init.
printf '# invoice-cli\n\n<!-- zuko:start — generated from OVERVIEW.md; edit that file, not this block -->\n<!-- zuko:end -->\n' >"$repo/README.md"
CLAUDE_PROJECT_DIR="$repo" bash "$scripts/render-readme-block.sh" --write 2>/dev/null
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "chore(spec): onboard invoice-cli"

gate() {
  gate_out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/verify-ship-gates.sh" docs/specs/export-csv.md 2>&1)
  gate_status=$?
}

commit() {      # commit <subject>
  git -C "$repo" add -A
  git -C "$repo" commit -q --no-verify -m "$1"
}

# Adds lines to CHANGELOG.md right after an existing one. awk reads "\n" in
# the new text as a line break.
after() {       # after <existing line> <new lines>
  awk -v at="$1" -v add="$2" '{ print } $0 == at { print add }' "$repo/CHANGELOG.md" >"$work/CHANGELOG.md"
  mv "$work/CHANGELOG.md" "$repo/CHANGELOG.md"
}

# 2. A feat branch with no line.
git -C "$repo" checkout -q -b feat/export-csv
echo "ledger" >>"$repo/exporters.py"
commit "feat(exporters): write ledger csv"
feat_sha=$(git -C "$repo" log -1 --format=%h)
gate
expect_exit 1 "$gate_status" "e2e: the gate refuses a feat branch with no changelog line"
expect_match '^- CHANGELOG\.md  no new line under \[Unreleased\] — this branch has feat or fix commits:$' \
  "$gate_out" "e2e: the gate says the line is missing"
expect_match "^ {16}$feat_sha feat\(exporters\): write ledger csv$" "$gate_out" "e2e: the gate names the commit that needs it"

# 3. /ship writes the line under Added.
after "## [Unreleased]" "\n### Added\n\n- Export the ledger as one CSV file."
commit "docs(changelog): note the csv export"
gate
expect_exit 0 "$gate_status" "e2e: the gate passes once the line is there"
expect_match '^Changelog: 1 new line under \[Unreleased\] for 1 feat/fix commit$' "$gate_out" "e2e: the gate prints the changelog scope line"
[ "$(sed -n '/^## \[Unreleased\]$/,/^## \[0\.2\.0\]/p' "$repo/CHANGELOG.md" | grep '^[-#]')" = "$(printf '## [Unreleased]\n### Added\n- Export the ledger as one CSV file.\n## [0.2.0] - 2025-05-19')" ]
expect_exit 0 "$?" "e2e: the line sits under Added in [Unreleased], above the past versions"

# 4. An attribution line slips in.
after "- Export the ledger as one CSV file." "- Generated with Claude Code"
commit "docs(changelog): credit the tool"
gate
expect_exit 1 "$gate_status" "e2e: the gate refuses an attributed changelog line"
expect_match '^- CHANGELOG\.md  new line carries Claude attribution: "- Generated with Claude Code"$' \
  "$gate_out" "e2e: the gate quotes the attributed line"

# 5. A chore-only branch off main needs no line.
git -C "$repo" checkout -q main
git -C "$repo" checkout -q -b chore/bump-ruff
echo "ruff==0.6.9" >>"$repo/requirements-dev.txt"
commit "chore(deps): bump ruff"
gate
expect_exit 0 "$gate_status" "e2e: the gate passes a chore branch with no changelog change"
expect_match '^Changelog: no feat or fix commits — no line needed$' "$gate_out" "e2e: the gate says no line was needed"

# 6. A breaking change, called out under Changed.
git -C "$repo" checkout -q main
git -C "$repo" checkout -q -b feat/config-v2
echo "[settings]" >>"$repo/invoice.toml"
after "## [Unreleased]" "\n### Changed\n\n- BREAKING: Settings move from settings.ini to invoice.toml; rename the file."
commit "feat(config)!: read settings from invoice.toml"
gate
expect_exit 0 "$gate_status" "e2e: the gate passes a breaking change with its line"
expect_match '^Naming: checked 1 commits on feat/config-v2 ahead of main\.$' "$gate_out" "e2e: the breaking-change commit was scanned"
expect_no_match 'subject is not' "$gate_out" "e2e: naming accepts the ! marker"
expect_match '^Changelog: 1 new line under \[Unreleased\] for 1 feat/fix commit$' "$gate_out" "e2e: the breaking line is counted"
