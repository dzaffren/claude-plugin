# One walk through strix-code. The release skill carries the Strix steps:
# start it, branch on its STRIX: line, judge its blocks, and write its rows.
# Then a scratch invoice-cli release runs release.py strix with a stub strix,
# builds the report from its blocks as the skill does, and cuts it twice: a
# confirmed medium passes, and a confirmed high blocks.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

work=$(mktemp -d -p "$work")
release="$scripts/lib/release.py"
fixtures="$scripts/tests/fixtures/strix-code"
skill="$scripts/../skills/release/SKILL.md"

# 1. The skill.
skill_text=$(cat "$skill")
skill_flat=$(tr '\n' ' ' <<<"$skill_text" | tr -s ' ')
command='python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" strix <repo-root> --scratch <the folder> --files <the files>'
grep -qF -e "$command" <<<"$skill_text"
expect_exit 0 "$?" "release skill: runs release.py strix from the plugin"
pick_at=$(grep -n 'release.py" pick <repo-root>' "$skill" | head -n 1 | cut -d: -f1)
strix_at=$(grep -n '^\*\*Start Strix\.\*\*' "$skill" | head -n 1 | cut -d: -f1)
dispatch_at=$(grep -n 'Dispatch the `zuko:pentester` agent' "$skill" | head -n 1 | cut -d: -f1)
[ -n "$pick_at" ] && [ -n "$strix_at" ] && [ -n "$dispatch_at" ] && [ "$pick_at" -lt "$strix_at" ] && [ "$strix_at" -lt "$dispatch_at" ]
expect_exit 0 "$?" "release skill: Strix starts after pick and before the dispatch"
expect_match 'Run this with `run_in_background`, and go on to the dispatch at once' "$skill_flat" "release skill: Strix runs next to the pentester"
expect_match 'branch on its last line, which starts `STRIX:`, and nothing else' "$skill_flat" "release skill: branches on the STRIX: line"
for state in 'missing · strix-agent 1\.7\.0' 'skipped · <why>' 'failed · <why>' 'done · …' 'stopped · …'; do
  expect_match "^\| \`STRIX: $state\` " "$skill_text" "release skill: the STRIX: table has $state"
done
expect_match '^Strix is not installed\. Install strix-agent 1\.7\.0 with uv tool install\? yes / skip$' "$skill_text" "release skill: the install question"
expect_match 'release\.py" strix-install <repo-root>' "$skill_flat" "release skill: yes runs strix-install"
expect_match 'On skip, print `Strix skipped: not installed`\.' "$skill_flat" "release skill: a skipped install says so"
expect_match 'A skip or a failure never stops the release \(D112\)' "$skill_flat" "release skill: Strix never stops the release"
expect_match 'Send each Strix `FINDING` block to its own verifier in the same way, blind \(D113\)\.' "$skill_flat" "release skill: each Strix block goes to a blind verifier"
expect_match '`CATEGORY` is the OWASP 2025 category from `owasp\.md` that fits the `CWE` and the title, then the CWE in brackets' "$skill_flat" "release skill: a Strix category is OWASP with the CWE"
expect_match '`BASE` is the same as for a pentester finding in that file\.' "$skill_flat" "release skill: a Strix finding gets the pentester's BASE"
expect_match 'A rejected one goes under Needs validation, and so does a block with `FILE: none`' "$skill_flat" "release skill: a rejected Strix finding needs validation"
expect_match 'Print each `OUTSIDE:` line to the user as it is\. It goes to no verifier and not into the report\.' "$skill_flat" "release skill: an OUTSIDE line stays in the terminal"
expect_match 'numbered `S1`, `S2` and on' "$skill_flat" "release skill: confirmed Strix findings are S rows"
expect_match '^   \| S1 \| medium \| A05:2025 Injection \(CWE-78\) \| ' "$skill_text" "release skill: the report example has an S row"
expect_match '^   \| N2 \| [^|]+ \| [^|]+ \| Strix: [^|]+ \| whether Strix.s proof reaches this line: zuko.s verifier could not trace it in the code \|$' "$skill_text" "release skill: the report example has a Strix N row"
expect_match '^   - STRIX 1\.7\.0 \(standard, anthropic/claude-sonnet-5-5\) — 3 found, 1 confirmed, 1 needs validation, 1 info dropped · \$3\.80 of \$10$' "$skill_text" "release skill: the report example has the STRIX line"
expect_no_match 'stopped at (its|the) \$10 budget' "$skill_text" "release skill: a stopped run names no cause that Strix does not give"
expect_match 'with `stopped before it finished · ` in front of the counts' "$skill_flat" "release skill: a stopped run says only that it stopped"
expect_match '`- STRIX — skipped: not installed`' "$skill_flat" "release skill: a skipped Strix goes under Not assessed"
expect_match 'The report never carries a Strix PoC\.' "$skill_flat" "release skill: no PoC in the report"
expect_match '^              strix: 1\.7\.0 standard · \$3\.80 of \$10 · 3 found · 1 confirmed · 1 needs validation · 1 info dropped · 9 outside$' "$skill_text" "release skill: the summary has the strix line"
expect_match '^  strix     1\.7\.0 standard · \$3\.80 of \$10 · 1 confirmed · 1 needs validation$' "$skill_text" "release skill: the step 7 report has the strix line"

# 2. A scratch invoice-cli release, a stub strix, docker and gh, and a Strix config.
mkdir -p "$work/bin" "$work/gh" "$work/fake/run" "$work/home/.strix"
export FAKE="$work/fake" FAKE_GH="$work/gh"
cp "$fixtures/"*.json "$FAKE/run/"
cat >"$work/bin/strix" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = "--version" ]; then echo "strix 1.7.0"; exit 0; fi
mkdir -p strix_runs/invoice-cli_a1b2
cp "$FAKE/run/"* strix_runs/invoice-cli_a1b2/
exit 2
STUB
printf '#!/usr/bin/env bash\necho "Server Version: 29.9.2"\n' >"$work/bin/docker"
cat >"$work/bin/gh" <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "api "*/check-runs*) echo '{"total_count": 0, "check_runs": []}' ;;
  "api "*/status*) echo '{"state": "pending", "total_count": 0, "statuses": []}' ;;
  "release view") echo "release not found" >&2; exit 1 ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$work/bin/strix" "$work/bin/docker" "$work/bin/gh"
PATH="$work/bin:$PATH"
printf '{"env": {"STRIX_LLM": "anthropic/claude-sonnet-5-5", "LLM_API_KEY": "sk-ant-test-0000"}}\n' >"$work/home/.strix/cli-config.json"

repo="$work/repo"
bare="$work/origin.git"
git init -q --bare "$bare"
mkdir -p "$repo/invoice_cli/exporters" "$repo/invoice_cli/importers"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester
git -C "$repo" remote add origin https://github.com/acme/invoice-cli.git
git -C "$repo" config "url.$bare.insteadOf" https://github.com/acme/invoice-cli.git
commit() {      # commit <message>
  git -C "$repo" add -A
  git -C "$repo" commit -q --no-verify -m "$1"
}
cat >"$repo/OVERVIEW.md" <<'OVERVIEW'
# invoice-cli

**Status:** Active · **Updated:** 2026-10-28 by /ship supplier-export

Turns a folder of supplier invoices into one ledger CSV.

## Run it

| Task    | Command            |
| ------- | ------------------ |
| install | `pip install -e .` |
| test    | `sh check.sh`      |
OVERVIEW
printf 'exit 0\n' >"$repo/check.sh"
printf 'print("bank")\n' >"$repo/invoice_cli/importers/bank.py"
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
for f in cli.py exporters/ledger.py exporters/suppliers.py; do
  printf 'print("%s")\n' "$f" >"$repo/invoice_cli/$f"
done
awk '{ print } $0 == "## [Unreleased]" { print "\n### Added\n\n- Export one CSV for each supplier." }' "$repo/CHANGELOG.md" >"$work/CHANGELOG.md"
mv "$work/CHANGELOG.md" "$repo/CHANGELOG.md"
commit "feat(exporters): one csv per supplier"
git -C "$repo" push -q origin main

# 3. release.py strix, with the range files as the skill joins them.
files=$(git -C "$repo" diff --name-only v1.4.2..HEAD | paste -sd, -)
scratch=$(mktemp -d -p "$work")
strix_out=$(HOME="$work/home" USERPROFILE="$work/home" python3 "$release" strix "$repo" --scratch "$scratch" --files "$files" 2>&1)
expect_exit 0 "$?" "strix: release.py strix exits 0"
strix_out=${strix_out//$'\r'/}
expect_match '^STRIX: done · 1\.7\.0 · standard · anthropic/claude-sonnet-5-5 · \$3\.80 of \$10 · 5 found · 1 info dropped · 1 outside · incomplete$' "$(tail -n 1 <<<"$strix_out")" "strix: the run is done, with its counts"
expect_match '^OUTSIDE: invoice_cli/importers/bank\.py:58 · low · ' "$strix_out" "strix: bank.py is outside the range"

# The skill's report, from the blocks: the verifier confirms the block with
# the given severity, at that severity, and rejects the others.
report() {     # report <severity confirmed> <file>: the report the skill writes
  printf '%s\n' "$strix_out" >"$work/strix.out"
  python3 - "$1" "$2" "$work/strix.out" <<'PY'
import re, sys
confirm, path = sys.argv[1], sys.argv[2]
blocks = re.findall(r"^FINDING (S\d+)\n(.*?)(?:\n\n|\Z)", open(sys.argv[3], encoding="utf-8").read(), re.M | re.S)
cats = {"CWE-89": "A05:2025 Injection", "CWE-78": "A05:2025 Injection", "CWE-494": "A08:2025 Software or Data Integrity Failures"}
found, needs = [], []
for _, body in blocks:
    f = dict(line.split(": ", 1) for line in body.splitlines())
    cat = "%s (%s)" % (cats[f["CWE"]], f["CWE"])
    where = f["FILE"] if f["FILE"] != "none" else "—"
    if f["SEVERITY"] == confirm and f["FILE"] != "none" and not found:
        found.append("| S1 | %s | %s | %s | %s |" % (f["SEVERITY"], cat, where, f["TITLE"]))
    else:
        needs.append("| N%d | %s | %s | Strix: %s | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |"
                     % (len(needs) + 1, cat, where, f["TITLE"]))
result = "blocked" if confirm in ("critical", "high") else "pass"
open(path, "w", encoding="utf-8", newline="\n").write("""# Pentest v1.5.0

**Result:** %s
**Mode:** code-level
**Range:** v1.4.2..a1b2c3d (1 commit)
**Date:** 2026-11-09

## Findings

| ID | Severity | Category | Where | Description |
| -- | -------- | -------- | ----- | ----------- |
%s

## Needs validation

| ID | Category | Where | Description | Unknown |
| -- | -------- | ----- | ----------- | ------- |
%s

## Assessed

- A05:2025 Injection — 2 subprocess calls, 1 SQL string
- STRIX 1.7.0 (standard, anthropic/claude-sonnet-5-5) — 5 found, 1 confirmed, 2 needs validation, 1 info dropped, 1 outside · $3.80 of $10 · incomplete

## Not assessed

- A01:2025 Broken Access Control — needs a running server (slice 5b)

## Files checked

- invoice_cli/cli.py
- invoice_cli/exporters/ledger.py
- invoice_cli/exporters/suppliers.py
""" % (result, "\n".join(found), "\n".join(needs)))
PY
}

snapshot() {   # snapshot: every file's bytes, the status and the tags, as one hash
  { git -C "$repo" status --porcelain; git -C "$repo" tag; git -C "$repo" rev-parse HEAD
    find "$repo" -path "$repo/.git" -prune -o -type f -print | sort | xargs cat; } | cksum
}

# Scenario 2: a confirmed high from Strix blocks the release.
report high "$work/blocked.md"
before=$(snapshot)
cut_out=$(python3 "$release" cut "$repo" --version 1.5.0 --date 2026-11-09 --pentest "$work/blocked.md" 2>&1)
expect_exit 1 "$?" "blocked: cut refuses a confirmed Strix high"
cut_out=${cut_out//$'\r'/}
expect_match '^Pentest blocked v1\.5\.0: 1 high$' "$cut_out" "blocked: cut says why"
expect_match '^  \| S1 \| high \| A05:2025 Injection \(CWE-89\) \| invoice_cli/exporters/ledger\.py:31 \| Ledger export builds ORDER BY / LIMIT from the --sort option \|$' "$cut_out" "blocked: cut prints the S1 row"
[ "$before" = "$(snapshot)" ]
expect_exit 0 "$?" "blocked: cut writes nothing"

# Scenario 1: a confirmed Strix medium goes into the report, and the rejected ones need validation.
report medium "$work/pass.md"
cut_out=$(python3 "$release" cut "$repo" --version 1.5.0 --date 2026-11-09 --pentest "$work/pass.md" 2>&1)
expect_exit 0 "$?" "pass: cut takes a report with a Strix medium (got: $(tail -n 1 <<<"$cut_out"))"
written="$repo/docs/security/v1.5.0/report.md"
expect_match '^\| S1 \| medium \| A05:2025 Injection \(CWE-78\) \| invoice_cli/exporters/suppliers\.py:29 \| ' "$(cat "$written")" "pass: the committed report has the S1 row"
expect_match '^\| N1 \| A05:2025 Injection \(CWE-89\) \| invoice_cli/exporters/ledger\.py:31 \| Strix: ' "$(cat "$written")" "pass: a rejected Strix finding needs validation"
expect_match '^\| N2 \| [^|]+ \| — \| Strix: The install script fetches a wheel over plain http \| ' "$(cat "$written")" "pass: a finding with no file needs validation"
expect_no_match 'vulnerabilities/vuln-|poc_script|DROP TABLE' "$(cat "$written")" "pass: the report carries no PoC"
expect_match 'Known medium issue: A05:2025 Injection \(CWE-78\) in invoice_cli/exporters/suppliers\.py' "$(cat "$repo/CHANGELOG.md")" "pass: the Security section names the Strix medium"
expect_match '2 leads need validation' "$(cat "$repo/CHANGELOG.md")" "pass: the Security section counts the Strix leads"
expect_match '^\| invoice_cli/exporters/ledger\.py \| lead in v1\.5\.0 \|$' "$(cat "$repo/docs/security/coverage.md")" "pass: a Strix lead keeps its file on the pick list"
[ ! -e "$repo/strix_runs" ]
expect_exit 0 "$?" "pass: Strix wrote nothing in the repo"
