# One walk through the attack classes. The copied Cloudflare files match the
# pin byte for byte and carry their credit. The pin check names an upstream
# change to a copied file. The pentester and the release step carry the
# contract. A report with class lines goes through cut, and its class finding
# reaches the changelog. Sourced by run.sh, which provides $scripts, $work and
# the expect_* helpers.

work=$(mktemp -d -p "$work")
release="$scripts/lib/release.py"
fixtures="$scripts/tests/fixtures/attack-classes"
classes="$scripts/../references/attack-classes"
agent="$scripts/../agents/pentester.md"
skill="$scripts/../skills/release/SKILL.md"
pin=c1c8a8c1471069fb0e188eeaff69b8e8db6564a8

# 1. Copy and credit: each file is the upstream blob at the pin.
blobs='6dbc9ecb3a5b9080e95b962869e8c7ab16cfdc20 LICENSE
02ba9039eca4cec811fefc77bce0d7349b379aae AI-AND-LLM.md
18a2beb4dbb554fb52b0a0293b8bd9108207f8fa ATTACK-CLASSES.md
8ba673e9e7e3d02f5518aa0219bcbeec7957531b CLIENT-SIDE.md
5569f76c7740744aa3f60aaa89eaefe275f2e6c9 CLOUD-AND-DEPLOYMENT.md
0cba1fa463b62c9b0caba710a201e29c1eecd0ec DATA-ISOLATION-AND-LIFECYCLE.md
d6230098651bff6348d3868c11f566bfb1306e7f DESKTOP-MOBILE-AND-LOCAL-IPC.md
86ff4920752661fc4a31a35ca4f962ace5dd5f48 MEMORY-SAFETY-AND-BINARY.md
b04ab88f852224838fdc9683d9fcccd858b0778a PROTOCOLS-RPC-AND-MESSAGING.md
bf96aed0803bc07471483ab129dea86759c3e305 SUPPLY-CHAIN-AND-RELEASE.md
1a099fa575cf52a61e9a627f91b61015120fa517 WEB-PROTOCOL-AND-AUTH.md'
while read -r blob name; do
  [ "$(git hash-object "$classes/$name" 2>/dev/null)" = "$blob" ]
  expect_exit 0 "$?" "attack classes: $name is the upstream blob at c1c8a8c"
done <<<"$blobs"
expected=$( { cut -d' ' -f2 <<<"$blobs"; echo README.md; } | LC_ALL=C sort | tr '\n' ' ')
listing=$(ls -A "$classes" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')
[ "$listing" = "$expected" ]
expect_exit 0 "$?" "attack classes: the folder holds the 11 copied files and README.md, nothing else"
readme=$(cat "$classes/README.md" 2>/dev/null)
expect_match "^Pinned: $pin\$" "$(tail -n 1 <<<"$readme")" "attack classes: the README's last line is the full pin"
readme_flat=$(tr '\n' ' ' <<<"$readme" | tr -s ' ')
for left_out in RESOURCE-EXHAUSTION-AND-AVAILABILITY.md SKILL.md RECONNAISSANCE.md HUNTING.md VALIDATION-AND-REPORTING.md; do
  expect_match "$left_out" "$readme_flat" "attack classes: the README names $left_out as left out"
done

# 2. The pin check, end to end: upstream changed one copied file and the
# README. A stand-in for gh answers only the compare from the pin to main.
mkdir -p "$work/pin-bin"
cat >"$work/pin-bin/gh" <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "api repos/cloudflare/security-audit-skill/compare/c1c8a8c1471069fb0e188eeaff69b8e8db6564a8...main")
    printf '%s\n' skills/security-audit/AI-AND-LLM.md README.md ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$work/pin-bin/gh"
pin_out=$(PATH="$work/pin-bin:$PATH" bash "$scripts/check-attack-pin.sh" 2>&1)
expect_exit 0 "$?" "pin check: exits 0"
pin_out=${pin_out//$'\r'/}
[ "$pin_out" = "attack-classes: upstream changed AI-AND-LLM.md after c1c8a8c. This pentest uses the pinned copy." ]
expect_exit 0 "$?" "pin check: prints exactly the notice that names AI-AND-LLM.md (got: $pin_out)"

# 3. The prompt: the pentester reads the index, zuko's rules win, and a lead
# with no proof is a LEAD block (D101). The release step runs the pin check
# first.
agent_text=$(cat "$agent")
agent_flat=$(tr '\n' ' ' <<<"$agent_text" | tr -s ' ')
expect_match '\$\{CLAUDE_PLUGIN_ROOT\}/references/attack-classes/ATTACK-CLASSES\.md' "$agent_text" "pentester: reads attack-classes/ATTACK-CLASSES.md"
expect_match '## 1b\. Class files' "$agent_text" "pentester: has the class-file step"
expect_match 'git diff --stat <RANGE>' "$agent_text" "pentester: matches target lines against the range"
expect_match "zuko's rules win" "$agent_flat" "pentester: zuko's rules win over a class file"
expect_match 'A lead without a run proof is not a finding\. When it meets the lead rules in step 4, write a LEAD block for it\.' "$agent_flat" "pentester: a lead without a proof is a LEAD block, not a finding"
expect_match 'Run the code under test through its tracked entry point' "$agent_flat" "pentester: proves through the tracked entry point"
expect_match 'Before you drop a lead because the hook refused a command, try the tracked entry point' "$agent_flat" "pentester: tries the entry point before it drops a lead"
expect_match '`subagent_type`: ignore it' "$agent_flat" "pentester: ignores subagent_type"
expect_match '`needs_validation`: write a LEAD block instead, as step 4 says\.' "$agent_flat" "pentester: a needs_validation verdict becomes a LEAD block"
expect_match 'RESOURCE-EXHAUSTION-AND-AVAILABILITY\.md` is not in the plugin' "$agent_flat" "pentester: knows the resource-exhaustion file is left out"
expect_match '^ +\{class file\} \(Cloudflare \{pin\}\) — \{classes used\}: \{files\}' "$agent_text" "pentester: the SCOPE template has an assessed class-file line"
expect_match '^ +\{class file\} \(Cloudflare \{pin\}\) — \{one-line reason\}' "$agent_text" "pentester: the SCOPE template has a not-assessed class-file line"
# {pin} is the commit after "Pinned: ", never the line's own first 7 characters,
# which are the word "Pinned:".
expect_match 'The `\{pin\}` in each class-file line is the first 7 characters of the commit after `Pinned: `' "$agent_flat" "pentester: {pin} is the first 7 characters of the pinned commit"
expect_exit 0 "$(sed -n 's/^Pinned: //p' <<<"$readme" | cut -c1-7 | grep -qx c1c8a8c; echo $?)" "pentester: the README's pinned commit gives c1c8a8c, as the examples show"
expect_match '^CATEGORY: \{A0N:2025 name\}, or \{A0N:2025 name\} · \{class file\} \{class\}$' "$agent_text" "pentester: CATEGORY can carry a class after the OWASP name"
expect_match 'Put the OWASP lines first in each list, then the class-file lines\.' "$agent_flat" "pentester: lists OWASP lines before class-file lines (D94)"
expect_match '^ +AI-AND-LLM \(Cloudflare c1c8a8c\) — no model call, prompt or agent in the range$' "$agent_text" "pentester: the example skips AI-AND-LLM and says why"
expect_match '^ +CLIENT-SIDE \(Cloudflare c1c8a8c\) — no browser code in the range$' "$agent_text" "pentester: the example skips CLIENT-SIDE and says why"
skill_text=$(cat "$skill")
pin_at=$(grep -n 'check-attack-pin\.sh' "$skill" | head -n 1 | cut -d: -f1)
dispatch_at=$(grep -n 'Dispatch the `zuko:pentester` agent' "$skill" | head -n 1 | cut -d: -f1)
[ -n "$pin_at" ] && [ -n "$dispatch_at" ] && [ "$pin_at" -lt "$dispatch_at" ]
expect_exit 0 "$?" "release skill: runs the pin check before it dispatches the pentester"
expect_match 'bash "\$\{CLAUDE_PLUGIN_ROOT\}/scripts/check-attack-pin\.sh"' "$skill_text" "release skill: runs check-attack-pin.sh from the plugin"
expect_match '^   - AI-AND-LLM \(Cloudflare c1c8a8c\) — ' "$skill_text" "release skill: the report example has a class-file line"
skill_flat=$(tr '\n' ' ' <<<"$skill_text" | tr -s ' ')
expect_match 'Put the OWASP lines first, then the class-file lines \(D94\)\.' "$skill_flat" "release skill: lists OWASP lines before class-file lines (D94)"
expect_match '· [0-9]+ class files$' "$skill_text" "release skill: the summary counts the class files read"
expect_match 'class files not read: [0-9]+ — no matching code in the range' "$skill_text" "release skill: the summary says which class files were not read"

# 4. A scratch invoice-cli release takes a report with class lines. The
# stand-in for gh has no CI checks and no release yet.
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

**Status:** Active · **Updated:** 2026-09-25 by /ship assistant

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

echo "assistant" >"$repo/assistant.py"
awk '{ print } $0 == "## [Unreleased]" { print "\n### Added\n\n- Ask the invoice assistant a question." }' "$repo/CHANGELOG.md" >"$work/CHANGELOG.md"
mv "$work/CHANGELOG.md" "$repo/CHANGELOG.md"
commit "feat(assistant): answer invoice questions"
git -C "$repo" push -q origin main

cut_out=$(python3 "$release" cut "$repo" --version 1.5.0 --date 2026-10-02 --pentest "$fixtures/report.md" 2>&1)
expect_exit 0 "$?" "attack-class report: cut takes it"
cut_out=${cut_out//$'\r'/}
expect_match '^  docs/security/v1\.5\.0/report\.md +pentest report, Result pass$' "$cut_out" "attack-class report: cut lists the report it wrote"
cmp -s "$repo/docs/security/v1.5.0/report.md" "$fixtures/report.md"
expect_exit 0 "$?" "attack-class report: the report is copied as given"

git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "chore(release): v1.5.0" -m "Changes CHANGELOG.md, OVERVIEW.md and the pentest report."
git -C "$repo" push -q origin main
expect_match '^docs/security/v1\.5\.0/report\.md$' "$(git -C "$bare" show --name-only --format= main)" "attack-class report: origin's release commit carries the report"
security='- Known medium issue: A05:2025 Injection · AI-AND-LLM tool-argument injection in invoice_cli/assistant/tools.py; see docs/security/v1.5.0/report.md.'
grep -qxF -e "$security" <<<"$(git -C "$bare" show main:CHANGELOG.md)"
expect_exit 0 "$?" "attack-class report: the CHANGELOG Security line carries the OWASP name and the class"

# D94 in the fixture: in each list, the OWASP lines come first and the
# class-file lines after. Section 3 checks the rule in the two prompts.
for heading in "## Assessed" "## Not assessed"; do
  items=$(awk -v h="$heading" '$0 == h { f = 1; next } /^## / { f = 0 } f && /^- /' "$fixtures/report.md" | tr '\n' '|')
  expect_match '\(Cloudflare c1c8a8c\)' "$items" "attack-class report: $heading has class-file lines"
  expect_no_match '\(Cloudflare c1c8a8c\).*\|- A[0-9]{2}:2025' "$items" "attack-class report: $heading lists OWASP lines before class-file lines"
done

# 5. The seed for the second seeded run: range.patch applies on llm-base/, and
# the agent runs offline from a recorded reply.
seed="$work/seed"
cp -R "$fixtures/llm-base" "$seed"
git -C "$seed" init -q -b main
git -C "$seed" config user.email t@example.com
git -C "$seed" config user.name Tester
git -C "$seed" add -A
git -C "$seed" -c commit.gpgsign=false commit -q -m base
git -C "$seed" tag -a v0.3.0 -m v0.3.0
git -C "$seed" apply --check "$fixtures/range.patch"
expect_exit 0 "$?" "llm seed: range.patch applies on llm-base"
git -C "$seed" apply "$fixtures/range.patch"
git -C "$seed" add -A
git -C "$seed" -c commit.gpgsign=false commit -q -m range
range_files=$(git -C "$seed" diff --name-only v0.3.0..HEAD)
expect_match '^helpdesk_agent/tools\.py$' "$range_files" "llm seed: the range changes the tool handlers"
expect_match '^skills/pr-summary/SKILL\.md$' "$range_files" "llm seed: the range adds the PR summary skill"
expect_match 'subprocess\.run\("wc -l " \+ path, shell=True' "$(cat "$seed/helpdesk_agent/tools.py")" "llm seed: count_lines passes the model's path to a shell"
answer=$(cd "$seed" && python3 -m helpdesk_agent.cli --replay examples/hello.json "How many words are in hello world?" 2>&1)
expect_match '^That text has 2 words\.' "$answer" "llm seed: the agent runs offline from a recorded reply"
