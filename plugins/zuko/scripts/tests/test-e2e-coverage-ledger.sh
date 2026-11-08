# One walk through the coverage ledger. The two prompts carry the OLD FILES
# and FILES CHECKED contract. Two releases of a scratch invoice-cli repo in a
# row each write docs/security/coverage.md, and pick reads it back. Sourced by
# run.sh, which provides $scripts, $work and the expect_* helpers.

work=$(mktemp -d -p "$work")
release="$scripts/lib/release.py"
fixtures="$scripts/tests/fixtures/coverage-ledger"
agent="$scripts/../agents/pentester.md"
skill="$scripts/../skills/release/SKILL.md"

# 1. The prompts. The pentester checks the old files as it checks the range,
# and lists each file it read and hunted.
agent_text=$(cat "$agent")
agent_flat=$(tr '\n' ' ' <<<"$agent_text" | tr -s ' ')
expect_match 'Leave out a file whose proof did not run' "$agent_flat" "pentester: a file with an unrun proof is not checked"
expect_match 'You are given `RANGE` \([^)]*\), `OLD FILES`' "$agent_flat" "pentester: OLD FILES is given with RANGE"
expect_match 'Check each file in `OLD FILES` as you check a file that the range changes\.' "$agent_flat" "pentester: checks each old file as a range file"
expect_match 'Use the same categories and the same class files as for the range' "$agent_flat" "pentester: an old file gets the range's categories and class files"
expect_match 'List only the files that you read and hunted\.' "$agent_flat" "pentester: FILES CHECKED lists only files it read and hunted"
expect_match '^FILES CHECKED: \{each file you read and hunted, from the range and from OLD FILES, joined with ", "\}$' "$agent_text" "pentester: the SCOPE template has FILES CHECKED"
scope_template=$(awk '/^SCOPE$/ { f = 1 } f && /^```/ { exit } f' "$agent")
expect_match '^FILES CHECKED: ' "$scope_template" "pentester: FILES CHECKED is in the SCOPE template block"
expect_match '^FILES CHECKED: invoice_cli/cli\.py, invoice_cli/importers/bank\.py, uv\.lock$' "$agent_text" "pentester: the SCOPE example has FILES CHECKED"

# The release step picks the old files after the pin check and before the
# dispatch, copies FILES CHECKED into the report, and repeats cut's Coverage
# line.
skill_text=$(cat "$skill")
skill_flat=$(tr '\n' ' ' <<<"$skill_text" | tr -s ' ')
pick='python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" pick <repo-root>'
grep -qF -e "$pick" <<<"$skill_text"
expect_exit 0 "$?" "release skill: runs release.py pick from the plugin"
pin_at=$(grep -n 'check-attack-pin\.sh' "$skill" | head -n 1 | cut -d: -f1)
pick_at=$(grep -nF -e "$pick" "$skill" | head -n 1 | cut -d: -f1)
dispatch_at=$(grep -n 'Dispatch the `zuko:pentester` agent' "$skill" | head -n 1 | cut -d: -f1)
[ -n "$pin_at" ] && [ -n "$pick_at" ] && [ -n "$dispatch_at" ] && [ "$pin_at" -lt "$pick_at" ] && [ "$pick_at" -lt "$dispatch_at" ]
expect_exit 0 "$?" "release skill: pick runs after the pin check and before the dispatch"
expect_match 'Print its lines to the user as they are\.' "$skill_flat" "release skill: prints pick's lines"
expect_match 'When `pick` exits 1, print its refusal' "$skill_flat" "release skill: prints a pick refusal"
# An old file is not in the release diff, so its finding or lead goes to the
# verifier with no diff to measure it by, and the verifier judges every line.
expect_match 'For a finding or a lead in a file from `OLD FILES`, send `BASE: none \(old file: every line of this file is in scope\)`' "$skill_flat" "release skill: an old file's finding or lead goes to the verifier with BASE none"
verifier_flat=$(tr '\n' ' ' <"$scripts/../agents/finding-verifier.md" | tr -s ' ')
expect_match 'With `BASE: none`, no diff limits the scope: every line of the file is in it\.' "$verifier_flat" "finding-verifier: BASE none puts every line in scope"
expect_match 'Then rule 3, rule 2 of a lead and "The issue existed before this diff" do not apply\.' "$verifier_flat" "finding-verifier: BASE none lifts the introduced-by-this-diff rules"
expect_match 'Then end before the pentest: nothing is written\.' "$skill_flat" "release skill: a pick refusal stops the release before the pentest"
expect_match 'Dispatch the `zuko:pentester` agent with `RANGE`, `OLD FILES`, `VERSION`' "$skill_flat" "release skill: gives OLD FILES with RANGE"
expect_match '`OLD FILES` is the paths that `pick` printed, joined with `, `, or `none`' "$skill_flat" "release skill: OLD FILES is pick's paths"
not_at=$(grep -n '^   ## Not assessed$' "$skill" | head -n 1 | cut -d: -f1)
checked_at=$(grep -n '^   ## Files checked$' "$skill" | head -n 1 | cut -d: -f1)
[ -n "$not_at" ] && [ -n "$checked_at" ] && [ "$not_at" -lt "$checked_at" ]
expect_exit 0 "$?" "release skill: the report example has Files checked after Not assessed"
files_section=$(awk '/^   ## Files checked$/ { f = 1; next } f && /^   ```$/ { exit } f && NF' "$skill")
expect_match '^   - invoice_cli/[a-z_/]+\.py$' "$files_section" "release skill: the Files checked example has one path in each line"
expect_no_match '^   [^-]' "$files_section" "release skill: the Files checked example holds only - path lines"
expect_match 'Copy each file in the `FILES CHECKED:` line into `## Files checked`, one in each line\.' "$skill_flat" "release skill: copies FILES CHECKED into the report"
expect_match '^              old files: 10 picked, 9 checked$' "$skill_text" "release skill: the summary counts the old files"
needs_line=$(grep -n '^              needs validation: ' "$skill" | head -n 1 | cut -d: -f1)
old_line=$(grep -n '^              old files: ' "$skill" | head -n 1 | cut -d: -f1)
[ -n "$needs_line" ] && [ -n "$old_line" ] && [ "$old_line" -eq $((needs_line + 1)) ]
expect_exit 0 "$?" "release skill: the old files line follows the needs validation line"
expect_match 'writes `docs/security/vX\.Y\.Z/report\.md` and `docs/security/coverage\.md`' "$skill_flat" "release skill: cut writes the coverage ledger"
expect_match 'Step 4 commits exactly the files it changed' "$skill_flat" "release skill: step 4 commits what cut wrote"
expect_match '^  coverage  13 of 148 files checked by a pentest · 135 not checked$' "$skill_text" "release skill: the step 7 report repeats the Coverage line"

# 2. Two releases of a scratch invoice-cli repo in a row. v1.5.0 starts the
# ledger with 3 range files and 10 old files, and a lead on cli.py. v1.6.0
# goes on from there: the lead file first, then the next unchecked files.
# The stand-in for gh has no CI checks and no release yet.
mkdir -p "$work/bin" "$work/gh"
export FAKE_GH="$work/gh"
cat >"$work/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_GH/calls"
case "$1 $2" in
  "api "*/check-runs*) echo '{"total_count": 0, "check_runs": []}' ;;
  "api "*/status*) echo '{"state": "pending", "total_count": 0, "statuses": []}' ;;
  "release view") echo "release not found" >&2; exit 1 ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"

repo="$work/repo"
bare="$work/origin.git"
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

unreleased() {  # unreleased <section> <line>: adds a line under [Unreleased]
  awk -v s="$1" -v l="$2" '{ print } $0 == "## [Unreleased]" { print "\n### " s "\n\n- " l }' "$repo/CHANGELOG.md" >"$work/CHANGELOG.md"
  mv "$work/CHANGELOG.md" "$repo/CHANGELOG.md"
}

release_commit() {  # release_commit <version>: commits, tags and pushes what cut wrote
  git -C "$repo" add -A
  git -C "$repo" commit -q --no-verify -m "chore(release): v$1" -m "Changes CHANGELOG.md, OVERVIEW.md, the pentest report and the coverage ledger."
  git -C "$repo" tag -a "v$1" -m "v$1"
  git -C "$repo" push -q --atomic origin main "v$1"
}

# Each path and its mark, one in each line, from the ledger's File and Mark
# table.
marks() { awk -F'|' 'NF == 4 && $2 !~ /^ *(File|-+) *$/ { gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $3); print $2 "\t" $3 }' <<<"$1"; }
mark_of() { awk -F'\t' -v p="$2" '$1 == p { print $2 }' <<<"$1"; }
count_of() { awk -F'\t' -v m="$2" '$2 == m { n++ } END { print n + 0 }' <<<"$1"; }
# The paths that pick printed, and the paths in a report's Files checked.
picked() { sed -n '2,$p' <<<"$1" | awk '{ print $1 }'; }
listed() { awk '/^## Files checked$/ { f = 1; next } /^## / { f = 0 } f && /^- / { print substr($0, 3) }' "$1" | LC_ALL=C sort; }
lines() { printf '%s\n' "$@"; }

# 25 units at the end. tests/, docs/ and a .md at the root are not units.
base_units=(
  check.sh
  invoice_cli/__init__.py invoice_cli/cli.py invoice_cli/config.py
  invoice_cli/currency.py invoice_cli/dates.py
  invoice_cli/exporters/__init__.py invoice_cli/exporters/csv_out.py
  invoice_cli/exporters/ledger.py invoice_cli/exporters/pdf.py
  invoice_cli/importers/__init__.py invoice_cli/importers/bank.py
  invoice_cli/importers/ocr.py invoice_cli/importers/statement.py
  invoice_cli/money.py invoice_cli/paths.py invoice_cli/report.py
  invoice_cli/rounding.py invoice_cli/suppliers.py invoice_cli/tax.py
  invoice_cli/totals.py invoice_cli/vat.py
  requirements.txt uv.lock
)
for path in "${base_units[@]}" tests/test_cli.py invoice_cli/tests/test_money.py docs/usage.md; do
  mkdir -p "$repo/$(dirname "$path")"
  printf '# %s\n' "$path" >"$repo/$path"
done
printf 'exit 0\n' >"$repo/check.sh"
cat >"$repo/OVERVIEW.md" <<'OVERVIEW'
# invoice-cli

**Status:** Active · **Updated:** 2026-09-25 by /ship supplier-export

Turns a folder of supplier invoices into one ledger CSV.

## Run it

| Task    | Command            |
| ------- | ------------------ |
| install | `pip install -e .` |
| test    | `sh check.sh`      |
OVERVIEW
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

# The v1.5.0 range: 3 units, and a doc that is not a unit.
range_v150=(invoice_cli/exporters/assistant.py invoice_cli/importers/bank.py uv.lock)
for path in "${range_v150[@]}" docs/usage.md; do
  printf 'changed in 1.5.0\n' >>"$repo/$path"
done
unreleased Added "Ask the assistant about an invoice."
commit "feat(exporters): an assistant for invoices"
git -C "$repo" push -q origin main

old_v150=(
  check.sh invoice_cli/__init__.py invoice_cli/cli.py invoice_cli/config.py
  invoice_cli/currency.py invoice_cli/dates.py invoice_cli/exporters/__init__.py
  invoice_cli/exporters/csv_out.py invoice_cli/exporters/ledger.py
  invoice_cli/exporters/pdf.py
)
pick_out=$(python3 "$release" pick "$repo" 2>&1)
expect_exit 0 "$?" "pick v1.5.0: runs with no ledger (got: $(head -n 1 <<<"$pick_out"))"
pick_out=${pick_out//$'\r'/}
expect_match '^Old files  10 of 22 not checked · no ledger yet, cut starts one$' "$(head -n 1 <<<"$pick_out")" "pick v1.5.0: says there is no ledger yet, and counts the 22 units outside the range"
[ "$(picked "$pick_out")" = "$(lines "${old_v150[@]}")" ]
expect_exit 0 "$?" "pick v1.5.0: the first 10 units outside the range, in path order"
[ "$(sed -n '2,$p' <<<"$pick_out" | sed -E 's/^  [^ ]+ +//' | sort -u)" = unchecked ]
expect_exit 0 "$?" "pick v1.5.0: each old file is unchecked"
[ ! -e "$repo/docs/security/coverage.md" ] && [ -z "$(git -C "$repo" status --porcelain)" ]
expect_exit 0 "$?" "pick v1.5.0: writes nothing"
[ "$(listed "$fixtures/report-v1.5.0.md")" = "$(lines "${range_v150[@]}" "${old_v150[@]}" | LC_ALL=C sort)" ]
expect_exit 0 "$?" "fixture v1.5.0: Files checked is the 3 range units and the 10 that pick printed"

cut_out=$(python3 "$release" cut "$repo" --version 1.5.0 --date 2026-10-02 --pentest "$fixtures/report-v1.5.0.md" 2>&1)
expect_exit 0 "$?" "cut v1.5.0: takes the report (got: $(tail -n 1 <<<"$cut_out"))"
cut_out=${cut_out//$'\r'/}
expect_match '^  docs/security/coverage\.md +coverage ledger, 13 of 25 checked$' "$cut_out" "cut v1.5.0: lists the ledger it wrote"
expect_match '^Coverage   13 of 25 files checked by a pentest · 12 not checked · ledger started$' "$cut_out" "cut v1.5.0: the Coverage line says this release started the ledger"
release_commit 1.5.0
expect_match '^docs/security/coverage\.md$' "$(git -C "$bare" show --name-only --format= main)" "v1.5.0: origin's release commit carries the ledger"
ledger=$(git -C "$bare" show main:docs/security/coverage.md 2>/dev/null)
expect_match '^\*\*Updated:\*\* v1\.5\.0 · 2026-10-02$' "$ledger" "ledger v1.5.0: Updated names the version and the date"
expect_match '^\*\*Units:\*\* 25 · \*\*Checked:\*\* 12 · \*\*Lead:\*\* 1 · \*\*Not checked:\*\* 12$' "$ledger" "ledger v1.5.0: the counts"
rows=$(marks "$ledger")
[ "$(cut -f1 <<<"$rows")" = "$(lines "${base_units[@]}" invoice_cli/exporters/assistant.py | LC_ALL=C sort)" ]
expect_exit 0 "$?" "ledger v1.5.0: one row for each unit, sorted by path, and none for tests, docs or a root .md"
expect_match '^lead in v1\.5\.0$' "$(mark_of "$rows" invoice_cli/cli.py)" "ledger v1.5.0: the file with lead N1 is marked lead in v1.5.0"
for path in "${range_v150[@]}" check.sh invoice_cli/exporters/pdf.py; do
  expect_match '^v1\.5\.0$' "$(mark_of "$rows" "$path")" "ledger v1.5.0: $path is marked v1.5.0"
done
expect_match '^12$' "$(count_of "$rows" v1.5.0)" "ledger v1.5.0: 12 files are marked v1.5.0"
expect_match '^12$' "$(count_of "$rows" unchecked)" "ledger v1.5.0: 12 files stay unchecked"
expect_match '^unchecked$' "$(mark_of "$rows" invoice_cli/importers/ocr.py)" "ledger v1.5.0: a file the run did not check is unchecked"

old_v160=(
  invoice_cli/cli.py invoice_cli/importers/__init__.py invoice_cli/importers/ocr.py
  invoice_cli/importers/statement.py invoice_cli/money.py invoice_cli/paths.py
  invoice_cli/report.py invoice_cli/rounding.py invoice_cli/suppliers.py
  invoice_cli/tax.py
)
pick_out=$(python3 "$release" pick "$repo" 2>&1)
expect_exit 0 "$?" "pick after v1.5.0: reads the ledger (got: $(head -n 1 <<<"$pick_out"))"
pick_out=${pick_out//$'\r'/}
expect_match '^Old files  10 of 13 not checked · docs/security/coverage\.md$' "$(head -n 1 <<<"$pick_out")" "pick after v1.5.0: counts the lead and the 12 unchecked files"
expect_match '^  invoice_cli/cli\.py +lead in v1\.5\.0$' "$(sed -n 2p <<<"$pick_out")" "pick after v1.5.0: the file with an open lead comes first"
[ "$(picked "$pick_out")" = "$(lines "${old_v160[@]}")" ]
expect_exit 0 "$?" "pick after v1.5.0: then the next 9 unchecked files in path order"

# The v1.6.0 range changes 2 files that v1.5.0 checked. cli.py does not
# change.
range_v160=(invoice_cli/exporters/ledger.py invoice_cli/importers/bank.py)
for path in "${range_v160[@]}"; do
  printf 'changed in 1.6.0\n' >>"$repo/$path"
done
unreleased Added "Round the ledger totals by currency."
commit "feat(exporters): round ledger totals by currency"
git -C "$repo" push -q origin main
[ "$(picked "$(python3 "$release" pick "$repo" 2>&1)")" = "$(lines "${old_v160[@]}")" ]
expect_exit 0 "$?" "pick v1.6.0: a range file that v1.5.0 checked is not an old file"
[ "$(listed "$fixtures/report-v1.6.0.md")" = "$(lines "${range_v160[@]}" "${old_v160[@]}" | LC_ALL=C sort)" ]
expect_exit 0 "$?" "fixture v1.6.0: Files checked is the 2 range units and the 10 that pick printed"

cut_out=$(python3 "$release" cut "$repo" --version 1.6.0 --date 2026-11-02 --pentest "$fixtures/report-v1.6.0.md" 2>&1)
expect_exit 0 "$?" "cut v1.6.0: takes the report (got: $(tail -n 1 <<<"$cut_out"))"
cut_out=${cut_out//$'\r'/}
expect_match '^  docs/security/coverage\.md +coverage ledger, 22 of 25 checked$' "$cut_out" "cut v1.6.0: lists the ledger it wrote"
expect_match '^Coverage   22 of 25 files checked by a pentest · 3 not checked$' "$cut_out" "cut v1.6.0: the Coverage line"
expect_no_match 'ledger started' "$cut_out" "cut v1.6.0: the ledger was already there"
release_commit 1.6.0
ledger=$(git -C "$bare" show main:docs/security/coverage.md 2>/dev/null)
expect_match '^\*\*Updated:\*\* v1\.6\.0 · 2026-11-02$' "$ledger" "ledger v1.6.0: Updated names the version and the date"
expect_match '^\*\*Units:\*\* 25 · \*\*Checked:\*\* 22 · \*\*Lead:\*\* 0 · \*\*Not checked:\*\* 3$' "$ledger" "ledger v1.6.0: the counts"
rows=$(marks "$ledger")
expect_match '^v1\.6\.0$' "$(mark_of "$rows" invoice_cli/cli.py)" "ledger v1.6.0: the lead file is checked with no lead"
for path in "${range_v160[@]}"; do
  expect_match '^v1\.6\.0$' "$(mark_of "$rows" "$path")" "ledger v1.6.0: range file $path is marked v1.6.0"
done
expect_match '^v1\.5\.0$' "$(mark_of "$rows" check.sh)" "ledger v1.6.0: a file that v1.5.0 checked and that did not change keeps v1.5.0"
expect_match '^12$' "$(count_of "$rows" v1.6.0)" "ledger v1.6.0: 12 files are marked v1.6.0"
expect_match '^10$' "$(count_of "$rows" v1.5.0)" "ledger v1.6.0: 10 files keep v1.5.0"
[ "$(awk -F'\t' '$2 == "unchecked" { print $1 }' <<<"$rows")" = "$(lines invoice_cli/totals.py invoice_cli/vat.py requirements.txt)" ]
expect_exit 0 "$?" "ledger v1.6.0: 3 files stay unchecked"

pick_out=$(python3 "$release" pick "$repo" 2>&1)
pick_out=${pick_out//$'\r'/}
expect_match '^Old files  3 of 3 not checked · docs/security/coverage\.md$' "$(head -n 1 <<<"$pick_out")" "pick after v1.6.0: the 3 files left"
[ "$(picked "$pick_out")" = "$(lines invoice_cli/totals.py invoice_cli/vat.py requirements.txt)" ]
expect_exit 0 "$?" "pick after v1.6.0: lists the 3 unchecked files in path order"
