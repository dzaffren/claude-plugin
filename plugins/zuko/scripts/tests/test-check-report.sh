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
import os, re, sys
text = open(os.path.join(os.environ["BOX"], "findings.txt")).read()
broken = eval(sys.argv[1])
# A mutation that changed nothing would leave the assertion below testing a
# conforming report and passing for the wrong reason.
assert broken != text, "mutation matched nothing: %s" % sys.argv[1]
open(os.path.join(os.environ["BOX"], "broken.txt"), "w").write(broken)
PY
}

# 1. Both examples out of the contract conform.
run "$box/findings.txt"
expect_exit 0 "$status" "the findings example in report.md conforms"
expect_match 'header, verdict, count line, 2 findings, 2 decisions, glossary \(3 words\), next step' "$out" "a passing run says what it checked"

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

mutate "re.sub(r'^  token .*' + chr(10), '', text, flags=re.M)"
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


# --- What the first review of this slice found -------------------------------
# Every case below is a report the checker used to pass, or a good report it
# used to reject.

minimal() {   # minimal > file -- the smallest conforming report
  cat <<'REPORT'
Review: feat/import — 1 files, 10 lines

One real problem. It hands back rows the caller should not see.
The reviewers raised 2 possible problems and 1 did not hold up on a second look.

1. The importer trusts the caller
   What breaks  The handler takes the account id from the address and never
                checks it against who is signed in.
   Costs you    One customer can read another customer's rows.
   Where        api/import.ts:12
   Fix          Check the signed-in account before reading.
   → Fix it, or skip it?

Next: answer each finding above, then /ship.
REPORT
}

minimal >"$box/minimal.txt"
run "$box/minimal.txt"
expect_exit 0 "$status" "the smallest conforming report passes"

# A finding nobody numbered is still a finding.
minimal | sed 's/^1\. The importer trusts the caller/The importer trusts the caller/' >"$box/unnumbered.txt"
run "$box/unnumbered.txt"
expect_exit 1 "$status" "a finding-shaped block with no number fails"
expect_match 'not numbered' "$out" "the unnumbered failure says what is wrong"

printf 'Review: feat/x — 1 files, 2 lines\n\nOne problem.\nThe reviewers raised 1 possible problem and it held.\n\nCritical: the importer trusts the caller\n\nNext: /ship\n' >"$box/sev-title.txt"
run "$box/sev-title.txt"
expect_exit 1 "$status" "a severity-titled line outside a numbered finding fails"
expect_match 'severity' "$out" "the severity failure says so"

# A word at the end of a sentence is a word.
minimal | sed 's/checks it against who is signed in./checks it against the session./' >"$box/fullstop.txt"
run "$box/fullstop.txt"
expect_exit 1 "$status" "a vocabulary word at a full stop is caught"
expect_match 'session' "$out" "the full-stop failure names the word"

# A two-word term wrapped across lines is the same term.
minimal | sed 's/The handler takes the account id from the address and never/The handler returns from inside its catch/; s/checks it against who is signed in./block without telling anyone./' >"$box/wrapped.txt"
run "$box/wrapped.txt"
expect_exit 1 "$status" "a two-word term split across lines is caught"
expect_match 'catch block' "$out" "the wrapped failure names the term"

# Labels in the wrong order.
python3 - <<PY
text = open("$box/minimal.txt").read()
where = "   Where        api/import.ts:12\n"
fix = "   Fix          Check the signed-in account before reading.\n"
open("$box/order.txt", "w").write(text.replace(where + fix, fix + where, 1))
PY
run "$box/order.txt"
expect_exit 1 "$status" "labels out of order fail"
expect_match 'out of order' "$out" "the order failure says so"

# The count line is a part, not scenery.
minimal | grep -v '^The reviewers raised' >"$box/nocount.txt"
run "$box/nocount.txt"
expect_exit 1 "$status" "a report with no count line fails"
expect_match 'count line' "$out" "the count failure names the count line"

# An honest title that happens to start with an ordinary word.
minimal | sed 's/^1\. The importer trusts the caller/1. High traffic makes the import stop halfway/' >"$box/high.txt"
run "$box/high.txt"
expect_exit 0 "$status" "a title starting with the word High is not a severity label"

# Two sentences per label, and no summary after the findings.
minimal | sed 's/   Costs you    One customer can read another customer.s rows./   Costs you    One customer reads another. It is not logged. Nobody notices./' >"$box/long.txt"
run "$box/long.txt"
expect_exit 1 "$status" "a label carrying three sentences fails"
expect_match 'two sentences' "$out" "the sentence failure says so"

minimal | sed 's|^Next: answer each finding above, then /ship.|In short: one problem, worth fixing before this ships.\n\nNext: answer each finding above, then /ship.|' >"$box/summary.txt"
run "$box/summary.txt"
expect_exit 1 "$status" "a closing summary after the findings fails"
expect_match 'summary' "$out" "the summary failure says so"

# The stripping the spike was run to protect, tested where it actually fires.
minimal | sed 's/One real problem. It hands back rows the caller should not see./One real problem, in api\/token.ts:9 and nowhere else./' >"$box/inline-path.txt"
run "$box/inline-path.txt"
expect_exit 0 "$status" "a file:line in the body is not read as an undefined word"

minimal | sed 's/One real problem. It hands back rows the caller should not see./One real problem. The token is the thing at fault./' >"$box/inline-word.txt"
run "$box/inline-word.txt"
expect_exit 1 "$status" "the same word as prose is still caught"
expect_match 'token' "$out" "the prose failure names the word"


# --- What the pull request's review found ------------------------------------

minimal | sed 's/^The reviewers raised 2 possible problems and 1 did not hold up on a second look./The reviewers raised 2 possible problems./' >"$box/half-count.txt"
run "$box/half-count.txt"
expect_exit 1 "$status" "a count line missing the held-up half fails"
expect_match 'count line' "$out" "the half-count failure names the count line"

minimal | sed 's/^One real problem. It hands back rows the caller should not see./One real problem. It hands back rows. It should not. It really should not./' >"$box/long-verdict.txt"
run "$box/long-verdict.txt"
expect_exit 1 "$status" "a verdict running to four sentences fails"
expect_match 'verdict' "$out" "the long-verdict failure names the verdict"

minimal | sed 's/^   → Fix it, or skip it?/   → skip/' >"$box/half-decision.txt"
run "$box/half-decision.txt"
expect_exit 1 "$status" "a decision that is not the question fails"
expect_match 'fix-or-skip' "$out" "the half-decision failure says so"

minimal | sed 's|^Next: answer each finding above, then /ship.|In short: one problem, worth fixing.\n\nGlossary\n  token           a secret string that stands in for permission to do something\n\nNext: answer each finding above, then /ship.|' >"$box/summary-before-glossary.txt"
run "$box/summary-before-glossary.txt"
expect_exit 1 "$status" "a summary between the last finding and the Glossary fails"
expect_match 'summary' "$out" "that failure names the summary, not something else"

minimal | sed 's/^1\. The importer trusts the caller/3. The importer trusts the caller/' >"$box/misnumbered.txt"
run "$box/misnumbered.txt"
expect_exit 1 "$status" "findings numbered out of sequence fail"
expect_match 'consecutive' "$out" "the numbering failure says what it wanted"

minimal | sed "s/^   Costs you    One customer can read another customer's rows./   Costs you    High: one customer can read another customer's rows./" >"$box/inline-severity.txt"
run "$box/inline-severity.txt"
expect_exit 1 "$status" "a severity label inside a label line fails"
expect_match 'severity' "$out" "the inline severity failure says so"

# The last finding's Fix must not swallow the decision, the Glossary and the
# next step when its sentences are counted.
minimal | sed 's|^Next: answer each finding above, then /ship.|Glossary\n  token           a secret string that stands in for permission to do something.\n\nNext: answer each finding above, then ship it.|' >"$box/tail-sentences.txt"
run "$box/tail-sentences.txt"
expect_exit 0 "$status" "a glossary and next step ending in full stops are not the last finding's sentences"

# A label may use its two sentences without the decision question counting as a
# third.
minimal | sed 's/^   Fix          Check the signed-in account before reading./   Fix          Check the signed-in account before reading. The helper for it already exists./' >"$box/two-sentence-fix.txt"
run "$box/two-sentence-fix.txt"
expect_exit 0 "$status" "a two-sentence Fix plus the question is two sentences, not three"

rm -rf "$box"
