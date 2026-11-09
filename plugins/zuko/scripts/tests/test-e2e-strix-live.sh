# One walk through strix-live. The release skill carries the live steps: for
# a staging target, strix-ready, the confirmation, and --live on a yes only.
# Then a scratch invoice-api release runs strix-ready and release.py strix
# --live with a stub strix, builds the report from its blocks as the skill
# does, and cuts it: a live high blocks. A code-level run of the same release
# gets one target, and its report passes.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

work=$(mktemp -d -p "$work")
release="$scripts/lib/release.py"
fixtures="$scripts/tests/fixtures/strix-live"
skill="$scripts/../skills/release/SKILL.md"
url="https://staging.invoice-api.example.net"

# 1. The skill.
skill_text=$(cat "$skill")
skill_flat=$(tr '\n' ' ' <<<"$skill_text" | tr -s ' ')
expect_match 'python3 "\$\{CLAUDE_PLUGIN_ROOT\}/scripts/lib/release\.py" strix-ready <repo-root>' "$skill_text" "release skill: a staging target runs strix-ready"
ready_at=$(grep -n 'release.py" strix-ready <repo-root>' "$skill" | head -n 1 | cut -d: -f1)
run_at=$(grep -n 'release.py" strix <repo-root> --scratch' "$skill" | head -n 1 | cut -d: -f1)
[ -n "$ready_at" ] && [ -n "$run_at" ] && [ "$ready_at" -lt "$run_at" ]
expect_exit 0 "$?" "release skill: strix-ready comes before the Strix run"
for state in 'ready · <version>' 'missing · strix-agent 1\.7\.0' 'skipped · <why>'; do
  expect_match "^ *\| \`STRIX: $state\` +\| " "$skill_text" "release skill: the strix-ready table has $state"
done
expect_match 'print `Strix skipped: <why>`, ask nothing, and start no Strix run' "$skill_flat" "release skill: a Strix that cannot run gets no question"
expect_match '^ *Strix will attack staging\.invoice-api\.example\.net with real requests\. zuko cannot hold it to this host or to reads only, and it may change or delete data there\. Staging should run a1b2c3d, the release HEAD\. Do you own this host and accept data loss on it\? yes / code-level$' "$skill_text" "release skill: the confirmation names the host, the guard, the data loss and the HEAD"
expect_match '`git rev-parse --short HEAD`' "$skill_flat" "release skill: the question takes the short HEAD"
expect_match 'Only the reply `yes` sends Strix live' "$skill_flat" "release skill: only yes sends Strix live"
expect_match 'print `Strix live skipped: the reply was not yes; Strix attacks the code only`' "$skill_flat" "release skill: any other reply is code-level"
expect_match 'D28 and D29 do not cover them \(D120\)' "$skill_flat" "release skill: says that no hook holds Strix"
expect_match '[Pp]rint `Strix live skipped: the Strix sandbox cannot reach 127\.0\.0\.1:5000; Strix attacks the code only`' "$skill_flat" "release skill: a localhost target keeps Strix to the code"
expect_match 'add `--live <the URL>`' "$skill_flat" "release skill: yes adds --live"
expect_match '`Strix running: standard · live <host> · up to \$10 · in the background, next to the pentester`' "$skill_flat" "release skill: the running line names the host"
expect_match 'has the `ENDPOINT` as its `Where`' "$skill_flat" "release skill: a live block with no file has its endpoint as Where"
expect_match "whether Strix's request reaches code in this release: Strix gave no code location" "$skill_flat" "release skill: the Unknown of a live block with no file"
expect_match '`\(standard, live · <the URL>, <model>\)`' "$skill_flat" "release skill: the Assessed line names the URL"
expect_match '`- STRIX live — code-level chosen for <host>`' "$skill_flat" "release skill: a code-level choice goes under Not assessed"
expect_match '`- STRIX live — skipped: localhost target`' "$skill_flat" "release skill: a localhost target goes under Not assessed"
expect_match 'as `N2 +<the path>`' "$skill_flat" "release skill: a live N row prints its PoC path"
expect_match '`strix: 1\.7\.0 standard · live staging\.invoice-api\.example\.net · \$6\.20 of \$10 · ' "$skill_flat" "release skill: the summary names the host"

# 2. A scratch invoice-api release, a stub strix and docker, and a Strix config.
mkdir -p "$work/bin" "$work/gh" "$work/fake/run" "$work/home/.strix"
export FAKE="$work/fake" FAKE_GH="$work/gh"
cp "$fixtures/"*.json "$FAKE/run/"
cat >"$work/bin/strix" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = "--version" ]; then echo "strix 1.7.0"; exit 0; fi
printf '%s\n' "$@" >"$FAKE/args"
mkdir -p strix_runs/invoice-api_c3d4
cp "$FAKE/run/"* strix_runs/invoice-api_c3d4/
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
mkdir -p "$repo/invoice_api"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester
git -C "$repo" remote add origin https://github.com/acme/invoice-api.git
git -C "$repo" config "url.$bare.insteadOf" https://github.com/acme/invoice-api.git
commit() {      # commit <message>
  git -C "$repo" add -A
  git -C "$repo" commit -q --no-verify -m "$1"
}
cat >"$repo/OVERVIEW.md" <<'OVERVIEW'
# invoice-api

**Status:** Active · **Updated:** 2026-11-02 by /ship invoice-list

Serves each customer's invoices over HTTP.

## Run it

| Task    | Command                                            |
| ------- | -------------------------------------------------- |
| install | `uv sync`                                          |
| run     | `uv run flask --app invoice_api run --port 5000`   |
| test    | `sh check.sh`                                      |
OVERVIEW
printf 'exit 0\n' >"$repo/check.sh"
printf 'app = None\n' >"$repo/invoice_api/__init__.py"
cat >"$repo/CHANGELOG.md" <<'LOG'
# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

## [2.6.0] - 2026-11-02

### Added

- List a customer's invoices.

[unreleased]: https://github.com/acme/invoice-api/compare/v2.6.0...HEAD
[2.6.0]: https://github.com/acme/invoice-api/compare/v2.5.0...v2.6.0
LOG
commit "chore: release 2.6.0"
git -C "$repo" tag -a v2.6.0 -m v2.6.0
git -C "$repo" push -q --atomic origin main v2.6.0
printf 'def get_invoice(invoice_id):\n    return invoice_id\n' >"$repo/invoice_api/routes.py"
awk '{ print } $0 == "## [Unreleased]" { print "\n### Fixed\n\n- An invoice id that is not a number answers 404." }' "$repo/CHANGELOG.md" >"$work/CHANGELOG.md"
mv "$work/CHANGELOG.md" "$repo/CHANGELOG.md"
commit "fix(routes): answer 404 for an invoice id that is not a number"
git -C "$repo" push -q origin main
files=$(git -C "$repo" diff --name-only v2.6.0..HEAD | paste -sd, -)

# 3. Scenario 1: strix-ready, then one live run on the copy and the URL.
ready_out=$(HOME="$work/home" USERPROFILE="$work/home" python3 "$release" strix-ready "$repo" 2>&1)
expect_exit 0 "$?" "ready: strix-ready exits 0"
expect_match '^STRIX: ready · 1\.7\.0$' "${ready_out//$'\r'/}" "ready: Strix is ready, so the skill asks"
[ ! -f "$FAKE/args" ]
expect_exit 0 "$?" "ready: strix-ready starts no run"

scratch=$(mktemp -d -p "$work")
strix_out=$(HOME="$work/home" USERPROFILE="$work/home" python3 "$release" strix "$repo" --scratch "$scratch" --files "$files" --live "$url" 2>&1)
expect_exit 0 "$?" "live: release.py strix --live exits 0"
strix_out=${strix_out//$'\r'/}
expect_match '^STRIX: done · 1\.7\.0 · standard · live staging\.invoice-api\.example\.net · anthropic/claude-sonnet-5-5 · \$6\.20 of \$10 · 2 found$' "$(tail -n 1 <<<"$strix_out")" "live: the run is done, live on the host"
expect_match "(^| )-t \\./release -t $url --scan-mode " "$(tr '\n' ' ' <"$FAKE/args")" "live: Strix gets the copy and the URL"
expect_match '^Send requests to staging\.invoice-api\.example\.net only\.$' "$(cat "$scratch/instruction.md")" "live: the instruction names the one host"

# The skill's report, from the blocks. The verifier confirms each block with a
# file when $1 is confirm, and rejects it otherwise. A block with no file goes
# to no verifier.
report() {     # report <confirm|reject> <mode line> <strix line> <file>: the report the skill writes
  printf '%s\n' "$strix_out" >"$work/strix.out"
  python3 - "$1" "$2" "$3" "$4" "$work/strix.out" <<'PY'
import re, sys
verdict, mode, strix_line, path = sys.argv[1:5]
blocks = re.findall(r"^FINDING (S\d+)\n(.*?)(?:\n\n|\Z)", open(sys.argv[5], encoding="utf-8").read(), re.M | re.S)
cats = {"CWE-639": "A01:2025 Broken Access Control", "CWE-306": "A01:2025 Broken Access Control"}
found, needs, high = [], [], False
for _, body in blocks:
    f = dict(line.split(": ", 1) for line in body.splitlines())
    cat = "%s (%s)" % (cats[f["CWE"]], f["CWE"])
    if f["FILE"] != "none" and verdict == "confirm":
        found.append("| S%d | %s | %s | %s get_invoice | %s |" % (len(found) + 1, f["SEVERITY"], cat, f["FILE"], f["TITLE"]))
        high = high or f["SEVERITY"] in ("critical", "high")
    elif f["FILE"] != "none":
        needs.append("| N%d | %s | %s get_invoice | Strix: %s | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |"
                     % (len(needs) + 1, cat, f["FILE"], f["TITLE"]))
    else:
        where = f.get("ENDPOINT", "none")
        needs.append("| N%d | %s | %s | Strix: %s | whether Strix's request reaches code in this release: Strix gave no code location |"
                     % (len(needs) + 1, cat, where if where != "none" else "—", f["TITLE"]))
open(path, "w", encoding="utf-8", newline="\n").write("""# Pentest v2.6.1

**Result:** %s
**Mode:** %s
**Range:** v2.6.0..a1b2c3d (1 commit)
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

- A01:2025 Broken Access Control — 1 route
%s

## Not assessed

- A07:2025 Authentication Failures — no test account
%s

## Files checked

- invoice_api/routes.py
""" % ("blocked" if high else "pass", mode, "\n".join(found), "\n".join(needs),
       strix_line if strix_line.startswith("- STRIX 1") else "",
       strix_line if strix_line.startswith("- STRIX live") else ""))
PY
}

snapshot() {   # snapshot: every file's bytes, the status and the tags, as one hash
  { git -C "$repo" status --porcelain; git -C "$repo" tag; git -C "$repo" rev-parse HEAD
    find "$repo" -path "$repo/.git" -prune -o -type f -print | sort | xargs cat; } | cksum
}

# Scenario 2: the live high blocks by its code; the finding with no code needs validation.
report confirm "live · $url" "- STRIX 1.7.0 (standard, live · $url, anthropic/claude-sonnet-5-5) — 2 found, 1 confirmed, 1 needs validation · \$6.20 of \$10" "$work/blocked.md"
expect_match '^\| N1 \| A01:2025 Broken Access Control \(CWE-306\) \| GET /admin/export \| Strix: Admin export reachable without a session \| ' "$(cat "$work/blocked.md")" "blocked: the live finding with no code has its endpoint as Where"
before=$(snapshot)
cut_out=$(python3 "$release" cut "$repo" --version 2.6.1 --date 2026-11-09 --pentest "$work/blocked.md" 2>&1)
expect_exit 1 "$?" "blocked: cut refuses a confirmed live high"
cut_out=${cut_out//$'\r'/}
expect_match '^Pentest blocked v2\.6\.1: 1 high$' "$cut_out" "blocked: cut says why"
expect_match '^  \| S1 \| high \| A01:2025 Broken Access Control \(CWE-639\) \| invoice_api/routes\.py:88 get_invoice \| Invoice of another customer readable by id \|$' "$cut_out" "blocked: cut prints the S1 row"
[ "$before" = "$(snapshot)" ]
expect_exit 0 "$?" "blocked: cut writes nothing"

# Scenario 3: the user answers code-level. Strix gets the copy only, and the report passes.
scratch=$(mktemp -d -p "$work")
strix_out=$(HOME="$work/home" USERPROFILE="$work/home" python3 "$release" strix "$repo" --scratch "$scratch" --files "$files" 2>&1)
strix_out=${strix_out//$'\r'/}
expect_match '^STRIX: done · 1\.7\.0 · standard · anthropic/claude-sonnet-5-5 · ' "$(tail -n 1 <<<"$strix_out")" "code-level: the done line names no host"
expect_match '(^| )-t \./release --scan-mode ' "$(tr '\n' ' ' <"$FAKE/args")" "code-level: Strix gets the copy only"
expect_no_match '^ENDPOINT:' "$strix_out" "code-level: no block has an ENDPOINT line"
expect_match 'Send no request to any host' "$(cat "$scratch/instruction.md")" "code-level: the instruction keeps Strix off the network"
report reject "live · $url" "- STRIX live — code-level chosen for staging.invoice-api.example.net" "$work/pass.md"
cut_out=$(python3 "$release" cut "$repo" --version 2.6.1 --date 2026-11-09 --pentest "$work/pass.md" 2>&1)
expect_exit 0 "$?" "code-level: cut takes the report (got: $(tail -n 1 <<<"$cut_out"))"
written="$repo/docs/security/v2.6.1/report.md"
expect_match '^- STRIX live — code-level chosen for staging\.invoice-api\.example\.net$' "$(cat "$written")" "code-level: the committed report says Strix stayed on the code"
expect_no_match 'vulnerabilities/vuln-|poc_script|curl -s' "$(cat "$written")" "code-level: the report carries no PoC"
[ ! -e "$repo/strix_runs" ]
expect_exit 0 "$?" "code-level: Strix wrote nothing in the repo"
