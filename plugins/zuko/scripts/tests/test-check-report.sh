# The whole slice in one walk: the examples are read out of references/report.md
# itself, so a contract edited without the checker following it fails here.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

refs="$scripts/../references"
checker="$scripts/check-report.sh"
box=$(mktemp -d)

# Pull one marked example out of the contract. Markers, not line numbers, so
# editing the prose around them does not move the test.
extract() {   # extract <name> > file
  REPORT_DOC="$refs/report.md" python3 - "$1" <<'PY'
import os, re, sys
doc = open(os.environ["REPORT_DOC"]).read()
block = re.search(r'<!-- example:%s -->\n```\n(.*?)```\n<!-- /example -->' % sys.argv[1],
                  doc, re.S)
sys.stdout.write(block.group(1))
PY
}

extract findings >"$box/findings.txt"
extract clean >"$box/clean.txt"

run() {       # run <file>; sets $out and $status
  out=$(bash "$checker" "$1" 2>&1)
  status=$?
}

# A mutation of the findings example, written to $box/broken.txt.
mutate() {    # mutate <python expression over `text`>
  BOX="$box" python3 - "$1" <<'PY'
import os, sys
text = open(os.path.join(os.environ["BOX"], "findings.txt")).read()
text = eval(sys.argv[1])
open(os.path.join(os.environ["BOX"], "broken.txt"), "w").write(text)
PY
}

# 1. Both examples out of the contract conform.
run "$box/findings.txt"
expect_exit 0 "$status" "the findings example in report.md conforms"
expect_match 'header, verdict, 2 findings, 2 decisions, glossary \(4 words\), next step' "$out" "a passing run says what it checked"

run "$box/clean.txt"
expect_exit 0 "$status" "the clean example in report.md conforms"
expect_match 'no findings' "$out" "a clean report is checked as a clean report"

# 2. One mutation per required part. Each names the part it broke.
mutate "text.split(chr(10), 1)[1]"
run "$box/broken.txt"
expect_exit 1 "$status" "a report with no header fails"
expect_match 'line 1 .*header' "$out" "the header failure names the line and the part"

mutate "text.replace('Two real problems. One lets a stranger read a shared report; the other hides a' + chr(10) + 'failure from the person who caused it.' + chr(10), '')"
run "$box/broken.txt"
expect_exit 1 "$status" "a report with no verdict fails"
expect_match 'verdict' "$out" "the verdict failure names the verdict"

mutate "text.replace('   Fix          Compare with crypto.timingSafeEqual — it takes the same time' + chr(10) + '                whatever the input.' + chr(10), '')"
run "$box/broken.txt"
expect_exit 1 "$status" "a finding with no Fix line fails"
expect_match 'finding 1.*Fix' "$out" "the label failure names which finding and which label"

mutate "text.replace('   → Fix it, or skip it?' + chr(10), '', 1)"
run "$box/broken.txt"
expect_exit 1 "$status" "a finding with no decision fails"
expect_match 'finding 1.*fix-or-skip' "$out" "the decision failure names which finding"

mutate "text.replace('  token           the secret string in a share link that proves you may read the report' + chr(10), '')"
run "$box/broken.txt"
expect_exit 1 "$status" "a report using a word it never defines fails"
expect_match "token" "$out" "the glossary failure names the undefined word"

mutate "text.replace('Next: answer each finding above, then /ship.' + chr(10), '')"
run "$box/broken.txt"
expect_exit 1 "$status" "a report with no next step fails"
expect_match 'next step' "$out" "the next-step failure says so"

mutate "text.replace('1. Anyone can guess a share link, given enough tries', '1. Critical: anyone can guess a share link')"
run "$box/broken.txt"
expect_exit 1 "$status" "a finding titled with a severity label fails"
expect_match 'severity' "$out" "the severity failure says so"

# 3. A glossary word inside a branch name or a file:line is not a word the
# report used. This is the spike's own grader bug, kept as a test.
python3 - <<PY
text = open("$box/clean.txt").read()
text = text.replace("Review: feat/share-links — 6 files, 240 lines",
                    "Review: feat/token-rotation — 6 files, 240 lines")
open("$box/paths.txt", "w").write(text)
PY
run "$box/paths.txt"
expect_exit 0 "$status" "a glossary word inside a branch name needs no definition"

# 4. Nothing to check is not a pass.
out=$(printf '' | bash "$checker" 2>&1); status=$?
expect_exit 2 "$status" "empty input exits 2"
expect_match 'nothing to check' "$out" "an empty input says so"

run "$box/does-not-exist.txt"
expect_exit 2 "$status" "a missing file exits 2"

rm -rf "$box"
