# One walk through the leads the pentest could not prove. The three prompts
# carry the LEAD contract. A report with a medium finding and 3 leads goes
# through cut, and the count line reaches the changelog and the notes. The seed
# for the seeded runs applies, and the lead that seeded run 2 sends names code
# in it. Sourced by run.sh, which provides $scripts, $work and the expect_*
# helpers.

work=$(mktemp -d -p "$work")
release="$scripts/lib/release.py"
fixtures="$scripts/tests/fixtures/needs-validation"
agent="$scripts/../agents/pentester.md"
verifier="$scripts/../agents/finding-verifier.md"
skill="$scripts/../skills/release/SKILL.md"

# 1. The prompts. The pentester writes a LEAD block where it dropped a lead
# (D101). The verifier judges a lead by its trace (D103). The release step
# sends each lead blind, without its CHECK, and writes the table.
agent_text=$(cat "$agent")
agent_flat=$(tr '\n' ' ' <<<"$agent_text" | tr -s ' ')
expect_match 'A finding is only what a run proved\.' "$agent_flat" "pentester: a run proof is the rule for findings"
expect_match '^LEAD: \{one sentence, the possible defect only\}$' "$agent_text" "pentester: the LEAD template starts with the claim"
expect_match '^TRACE: \{the input, then each file:line it passes, to the line where harm would happen\}$' "$agent_text" "pentester: the LEAD template has TRACE"
expect_match '^UNKNOWN: \{the one fact that decides it, which no run in the scratch copy can observe\}$' "$agent_text" "pentester: the LEAD template has UNKNOWN"
expect_match '^CHECK: \{a safe check the user can run to settle the fact\}$' "$agent_text" "pentester: the LEAD template has CHECK"
lead_template=$(awk '/^LEAD: \{/ { f = 1 } f && /^```/ { exit } f' "$agent")
expect_no_match '^(SEVERITY|PROOF): ' "$lead_template" "pentester: the LEAD template has no SEVERITY and no PROOF"
expect_match '^UNKNOWN: whether cygpath -m on Git Bash maps /c/work/shop to C:/work/shop$' "$agent_text" "pentester: the LEAD example names the one unknown fact"
expect_match '^CHECK: in Git Bash on Windows, run `cygpath -m -- /c/work/shop` and expect C:/work/shop$' "$agent_text" "pentester: the LEAD example has a safe check"
expect_match 'A lead has exactly one `UNKNOWN`\.' "$agent_flat" "pentester: a lead has exactly one UNKNOWN"
expect_match 'A lead is never a finding with its proof left out\.' "$agent_flat" "pentester: a provable lead is a finding"
expect_match 'A lead that is out of turns, or that needs more reading, is not a lead\.' "$agent_flat" "pentester: an unfinished trace is not a lead"
expect_match 'The \*\*Never a finding\*\* list \(D5\) stops a lead' "$agent_flat" "pentester: D5 stops a lead"
expect_match 'An untrusted-text lead needs a `TRACE` that reaches a tool call or a file write \(D6\)\.' "$agent_flat" "pentester: D6 stops an untrusted-text lead"
expect_match "A class file's \`needs_validation\` verdict is a LEAD block\." "$agent_flat" "pentester: a class file's needs_validation becomes a LEAD block"
expect_no_match 'Never write `needs_validation`' "$agent_flat" "pentester: the old needs_validation rule is gone"
expect_no_match 'is dropped\. Never report it' "$agent_flat" "pentester: the old drop rule is gone"

verifier_text=$(cat "$verifier")
verifier_flat=$(tr '\n' ' ' <<<"$verifier_text" | tr -s ' ')
second_at=$(grep -n '^A second exception to rule 1' "$verifier" | head -n 1 | cut -d: -f1)
lead_at=$(grep -n '^## A lead$' "$verifier" | head -n 1 | cut -d: -f1)
defence_at=$(grep -n '^## Reject on a defence only when you read it$' "$verifier" | head -n 1 | cut -d: -f1)
[ -n "$second_at" ] && [ -n "$lead_at" ] && [ -n "$defence_at" ] && [ "$second_at" -lt "$lead_at" ] && [ "$lead_at" -lt "$defence_at" ]
expect_exit 0 "$?" "verifier: the lead section follows the two exceptions to rule 1"
expect_match 'A claim that starts with `KIND: lead` is a lead\.' "$verifier_flat" "verifier: KIND: lead marks a lead"
expect_match 'With no `KIND` line, the claim is a finding' "$verifier_flat" "verifier: no KIND line is a finding, so /review does not change"
expect_match 'Each step of the `TRACE` is in the code as written' "$verifier_flat" "verifier: a lead's trace is in the code as written"
expect_match 'The repo does not answer the `UNKNOWN`' "$verifier_flat" "verifier: the repo does not settle the unknown"
expect_match 'A rejection on a defence still needs its `DEFENCE:` line' "$verifier_flat" "verifier: a lead rejected on a defence cites it"
expect_match 'For a lead, leave out `SEVERITY`, `ATTACKER` and `GAIN`\.' "$verifier_flat" "verifier: a lead verdict has no severity"
expect_match '^PATH: "/c/work/shop" reaches native_path unchanged from block-dangerous\.sh:84; the result decides which repo.s branch the guard reads\.$' "$verifier_text" "verifier: the lead example"
lead_example=$(awk '/^## A lead$/ { f = 1; next } /^## / { f = 0 } f' "$verifier")
expect_no_match '^(SEVERITY|ATTACKER|GAIN): ' "$lead_example" "verifier: the lead example has no SEVERITY, ATTACKER or GAIN"

skill_text=$(cat "$skill")
skill_flat=$(tr '\n' ' ' <<<"$skill_text" | tr -s ' ')
expect_match 'LEAD blocks, each with a `TRACE`, an `UNKNOWN` and a `CHECK`' "$skill_flat" "release skill: the pentester also returns LEAD blocks"
expect_match 'with `KIND: lead` first and no `SEVERITY`' "$skill_flat" "release skill: sends each lead with KIND: lead"
expect_match 'Never send `CHECK`\.' "$skill_flat" "release skill: never sends a lead's CHECK"
findings_at=$(grep -n '^   ## Findings$' "$skill" | head -n 1 | cut -d: -f1)
needs_at=$(grep -n '^   ## Needs validation$' "$skill" | head -n 1 | cut -d: -f1)
assessed_at=$(grep -n '^   ## Assessed$' "$skill" | head -n 1 | cut -d: -f1)
[ -n "$findings_at" ] && [ -n "$needs_at" ] && [ -n "$assessed_at" ] && [ "$findings_at" -lt "$needs_at" ] && [ "$needs_at" -lt "$assessed_at" ]
expect_exit 0 "$?" "release skill: the report example has Needs validation between Findings and Assessed"
expect_match '^   \| ID \| Category \| Where \| Description \| Unknown \|$' "$skill_text" "release skill: the Needs validation columns"
expect_match '^   \| N1 \| ' "$skill_text" "release skill: the report example has a lead row N1"
expect_match 'from the confirmed findings and the confirmed leads only' "$skill_flat" "release skill: the table holds the confirmed leads only"
expect_match 'The `## Needs validation` section is always there\.' "$skill_flat" "release skill: the section is always there"
expect_match 'never carries a `TRACE` or a `CHECK`' "$skill_flat" "release skill: the public report has no trace and no check"
expect_match '^   N1  [^ ]+:[0-9]+ [a-z_]+$' "$skill_text" "release skill: each lead prints with its place"
for label in trace unknown check; do
  expect_match "^       $label +[^ ]" "$skill_text" "release skill: each lead prints its $label"
done
expect_match '^              needs validation: 1 lead \(2 dropped by the verifier\)$' "$skill_text" "release skill: the summary counts the leads"
expect_match '^  pentest   passed: [0-9]+ critical, [0-9]+ high, [0-9]+ medium, [0-9]+ low · 1 lead needs validation · docs/security/' "$skill_text" "release skill: the step 7 report counts the leads"

# 2. A scratch invoice-cli release takes a report with a medium finding and
# 3 leads. The stand-in for gh has no CI checks and no release yet.
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
printf 'exit 0\n' >"$repo/check.sh"
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

echo "suppliers" >"$repo/suppliers.py"
awk '{ print } $0 == "## [Unreleased]" { print "\n### Added\n\n- Export one CSV for each supplier." }' "$repo/CHANGELOG.md" >"$work/CHANGELOG.md"
mv "$work/CHANGELOG.md" "$repo/CHANGELOG.md"
commit "feat(exporters): one csv per supplier"
git -C "$repo" push -q origin main

cut_out=$(python3 "$release" cut "$repo" --version 1.5.0 --date 2026-10-02 --pentest "$fixtures/report.md" 2>&1)
expect_exit 0 "$?" "lead report: cut takes it (got: $(tail -n 1 <<<"$cut_out"))"
cut_out=${cut_out//$'\r'/}
expect_match '^  docs/security/v1\.5\.0/report\.md +pentest report, Result pass$' "$cut_out" "lead report: cut lists the report it wrote"
cmp -s "$repo/docs/security/v1.5.0/report.md" "$fixtures/report.md"
expect_exit 0 "$?" "lead report: the report is copied as given"

git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "chore(release): v1.5.0" -m "Changes CHANGELOG.md, OVERVIEW.md and the pentest report."
git -C "$repo" tag -a v1.5.0 -m v1.5.0
git -C "$repo" push -q --atomic origin main v1.5.0
expect_match '^docs/security/v1\.5\.0/report\.md$' "$(git -C "$bare" show --name-only --format= main)" "lead report: origin's release commit carries the report"
origin_report=$(git -C "$bare" show main:docs/security/v1.5.0/report.md 2>/dev/null)
expect_match '^\| N1 +\| A05:2025 Injection +\| invoice_cli/exporters/suppliers\.py:29 export_suppliers +\|' "$origin_report" "lead report: the report on origin has the lead N1"
known='- Known medium issue: A05:2025 Injection in invoice_cli/importers/statement.py; see docs/security/v1.5.0/report.md.'
count='- 3 leads need validation; see docs/security/v1.5.0/report.md.'
security=$(printf '### Security\n\n%s\n%s' "$known" "$count")
origin_log=$(git -C "$bare" show main:CHANGELOG.md 2>/dev/null)
grep -qxF -e "$known" <<<"$origin_log"
expect_exit 0 "$?" "lead report: the CHANGELOG Security section has the known-issue line"
[ "$(awk '/^### Security$/ { f = 1 } /^## / { f = 0 } f && NF' <<<"$origin_log")" = "$(grep -v '^$' <<<"$security")" ]
expect_exit 0 "$?" "lead report: the count line follows the known-issue line in the CHANGELOG Security section"

python3 "$release" notes "$repo" --version 1.5.0 >"$work/notes.md"
expect_exit 0 "$?" "lead report: notes prints the section"
[ "$(sed -n '/^### Security$/,$p' "$work/notes.md")" = "$security" ]
expect_exit 0 "$?" "lead report: the notes end with the known issue and the count line"
expect_no_match 'cmd\.exe|branch protection|write_note' "$(cat "$work/notes.md")" "lead report: the release notes name no lead, only the count"

# 3. The seed for seeded runs 1 and 2: range.patch applies on base/ with the
# bank import of the pentest range, and lead-n2.txt names its code.
seed="$work/seed"
cp -R "$scripts/tests/fixtures/pentest/base" "$seed"
git -C "$seed" init -q -b main
git -C "$seed" config user.email t@example.com
git -C "$seed" config user.name Tester
git -C "$seed" add -A
git -C "$seed" -c commit.gpgsign=false commit -q -m base
git -C "$seed" tag -a v1.4.2 -m v1.4.2
git -C "$seed" apply "$scripts/tests/fixtures/pentest/range.patch"
git -C "$seed" apply --check "$fixtures/range.patch"
expect_exit 0 "$?" "lead seed: range.patch applies on base/ with the pentest range"
git -C "$seed" apply "$fixtures/range.patch"
git -C "$seed" add -A
git -C "$seed" -c commit.gpgsign=false commit -q -m range
range_files=$(git -C "$seed" diff --name-only v1.4.2..HEAD)
expect_match '^invoice_cli/importers/bank\.py$' "$range_files" "lead seed: the range keeps the bank import"
expect_match '^invoice_cli/exporters/suppliers\.py$' "$range_files" "lead seed: the range adds the supplier export"
suppliers="$seed/invoice_cli/exporters/suppliers.py"
nt_at=$(grep -n '^        if os\.name == "nt":$' "$suppliers" | cut -d: -f1)
shell_at=$(grep -n '^            subprocess\.run("start " + target, shell=True)$' "$suppliers" | cut -d: -f1)
[ -n "$nt_at" ] && [ -n "$shell_at" ] && [ "$nt_at" -lt "$shell_at" ] && [ "$shell_at" -le $((nt_at + 2)) ]
expect_exit 0 "$?" "lead seed: the shell string is built only under os.name == \"nt\""
expect_match '^INVOICE_NUMBER = re\.compile\(r"\^INV-\(\\d\+-\?\)\+\$"\)$' "$(cat "$suppliers")" "lead seed: the invoice-number regex nests a repeat"
printf 'number,supplier,amount\nINV-1,acme,10.00\nINV-2,globex,5.50\n' >"$seed/invoices.csv"
expect_match '^2 exports$' "$(cd "$seed" && python3 -m invoice_cli.cli export invoices.csv 2>&1)" "lead seed: the export runs through its entry point on Linux"

lead=$(cat "$fixtures/lead-n2.txt")
expect_match '^KIND: lead$' "$(head -n 1 <<<"$lead")" "lead n2: KIND: lead comes first"
for field in LEAD CATEGORY FILE SYMBOL SNIPPET TRACE UNKNOWN BASE; do
  expect_match "^$field: [^ ]" "$lead" "lead n2: has $field"
done
expect_no_match '^(CHECK|SEVERITY|PROOF): ' "$lead" "lead n2: no CHECK, SEVERITY or PROOF"
file_line=$(sed -n 's/^FILE: //p' <<<"$lead")
snippet=$(sed -n 's/^SNIPPET: //p' <<<"$lead")
at=${file_line##*:}
[ -n "$snippet" ] && [ "$(sed -n "${at}p" "$seed/${file_line%:*}" | sed 's/^ *//')" = "$snippet" ]
expect_exit 0 "$?" "lead n2: the SNIPPET is the line at FILE in the seed"
refuse_at=$(grep -n '^        if "/" in supplier or "\\\\" in supplier:$' "$suppliers" | cut -d: -f1)
[ -n "$refuse_at" ] && [ "$refuse_at" -lt "$at" ]
expect_exit 0 "$?" "lead n2: a check that refuses / and \\ runs before the line it names"
