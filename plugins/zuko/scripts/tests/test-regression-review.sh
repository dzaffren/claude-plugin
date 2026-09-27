# Regression-aware review is prompt text, so this checks the text is there:
# the "introduced by the diff" rule in all three review files, the history
# step, the new finding and verdict fields, the coverage lens, and owasp.md's
# six silent-failure shapes. It also builds the seeded repo and checks its
# history and the lines the spec cites. The seeded run itself is recorded in
# docs/specs/regression-review.md.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

work=$(mktemp -d -p "$work")
zuko=$(dirname "$scripts")
owasp="$zuko/references/owasp.md"
reviewer="$zuko/agents/reviewer.md"
verifier="$zuko/agents/finding-verifier.md"
skill="$zuko/skills/review/SKILL.md"
fixture="$here/fixtures/regression-review"

# The file with every run of whitespace folded to one space, so a phrase that
# wraps across lines still matches.
flat() { [ -f "$1" ] && tr -s '[:space:]' ' ' <"$1" || echo "(missing: $1)"; }

sk=$(flat "$skill")
rv=$(flat "$reviewer")
fv=$(flat "$verifier")

# --- the old reject rule is gone from all three files ---
for name in SKILL.md reviewer.md finding-verifier.md; do
  case $name in
    SKILL.md) text=$sk ;;
    reviewer.md) text=$rv ;;
    *) text=$fv ;;
  esac
  expect_no_match '[Aa] line the diff touched|[Ll]ines the diff did not touch|a line this diff actually changed' \
    "$text" "$name drops the touched-lines rule"
done

# --- the new rule: introduced by the diff, deleted lines and callers included ---
expect_match 'newly reached by a changed caller' "$sk" "SKILL.md rejects only what the diff did not add, delete or newly reach"
expect_match 'a problem this diff introduced' "$fv" "finding-verifier.md's rule 3 asks whether the diff introduced the problem"
expect_match '[Dd]eleted line' "$fv" "finding-verifier.md says a deleted line qualifies"
expect_match 'changed caller' "$fv" "finding-verifier.md says a changed caller qualifies"
expect_match 'changed caller' "$rv" "reviewer.md reports a changed caller"

# --- history for removed security code, and the raise ---
expect_match 'git log -S' "$rv" "reviewer.md runs git log -S on a removed security line"
expect_match 'git show --no-patch' "$rv" "reviewer.md reads the adding commit with git show --no-patch"
expect_match 'one tier' "$rv" "reviewer.md raises the severity one tier"
expect_match 'capped at critical' "$rv" "reviewer.md caps the raise at critical"
expect_match '^allowed-tools: .*Bash\(git show \*\)' "$(cat "$skill")" "SKILL.md's allowed-tools grants git show"
expect_match '^allowed-tools: .*Bash\(git log \*\)' "$(cat "$skill")" "SKILL.md's allowed-tools grants git log"
# O4: git log -S finds the adding commit, so git blame is left out.
expect_no_match 'git blame' "$sk" "SKILL.md does not grant git blame"

# --- the reviewer's new fields and the coverage lens ---
for field in 'CHANGE:' 'EVIDENCE:' 'RAISED:'; do
  expect_match "$field" "$rv" "reviewer.md's format carries $field"
done
expect_match 'added`?, `?deleted`?,? or `?caller' "$rv" "reviewer.md's CHANGE is added, deleted or caller"
expect_match '\*\*Coverage\*\*' "$rv" "reviewer.md has a Coverage lens"
expect_match 'CATEGORY: .*coverage' "$rv" "reviewer.md's CATEGORY includes coverage"
expect_match '[Ff]ive lenses' "$rv" "reviewer.md runs five lenses"

# --- the verifier: a defence it read, and who gains ---
for field in 'DEFENCE:' 'ATTACKER:' 'GAIN:'; do
  expect_match "$field" "$fv" "finding-verifier.md's output carries $field"
done
expect_match '[Aa] comment .{0,60}is not a defence' "$fv" "finding-verifier.md says a comment is not a defence"
expect_match 'EVIDENCE' "$fv" "finding-verifier.md reads EVIDENCE"
expect_match 'never from memory' "$fv" "finding-verifier.md checks EVIDENCE with git, never from memory"

# --- the skill: keeps an uncited rejection, passes EVIDENCE, reports the new lines ---
expect_match 'verifier cited no defence' "$sk" "SKILL.md keeps a finding whose rejection cites no defence"
expect_match 'EVIDENCE' "$sk" "SKILL.md passes EVIDENCE to the verifier"
expect_match '\(deleted\)' "$sk" "SKILL.md's report marks a deleted line"
expect_match 'raised: ' "$sk" "SKILL.md's report has the raised: line"
expect_match 'correctness, coverage, decisions' "$sk" "SKILL.md orders coverage between correctness and decisions"

# --- silent failures point at A10 ---
expect_match '[Ss]ilent failure.{0,80}A10|A10.{0,80}[Ss]ilent failure' "$sk" "SKILL.md's silent-failure bullet points to A10"
expect_match '[Ss]ilent failure.{0,80}A10|A10.{0,80}[Ss]ilent failure' "$rv" "reviewer.md's silent-failure bullet points to A10"

# A10's section, flattened and lowercased so a shape matches however it is cased.
a10=$(awk '$0 == "## A10:2025 Mishandling of Exceptional Conditions" { on = 1; next }
  on && /^## / { exit } on { print }' "$owasp" | tr -s '[:space:]' ' ' | tr '[:upper:]' '[:lower:]')
for shape in 'empty catch' 'log and continue' 'default returned on error' \
  'optional chaining' 'retries exhausted silently' 'failing open'; do
  expect_match "$shape" "$a10" "owasp.md's A10 names the shape: $shape"
done
expect_match 'log and re-raise' "$a10" "owasp.md's A10 says log and re-raise is not a finding"
expect_match 'logs its final failure' "$a10" "owasp.md's A10 says a retry that logs its final failure is not a finding"

# --- the seeded repo: real history, and the lines the spec cites ---
repo="$work/invoice-api"
bash "$fixture/build.sh" "$repo" >"$work/build.out" 2>&1
expect_exit 0 $? "build.sh builds the seeded repo"
# No global or system config, so colour or decoration on the machine cannot
# change the output the checks match.
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$repo" "$@" 2>/dev/null; }

expect_match '^feat/public-export$' "$(g branch --show-current)" "the seeded repo is on feat/public-export"
expect_match '^[0-9a-f]+ fix\(security\): require login on /export$' \
  "$(g log -S'@login_required' --oneline main -- routes/export.py)" \
  "git log -S'@login_required' on main prints the fix(security) commit"

expect_match '^@login_required$' "$(g show main:routes/export.py | sed -n 14p)" "routes/export.py:14 on main is @login_required"
# Every changed line, blank ones included; only the file headers are dropped.
export_changes=$(g diff --unified=0 main...HEAD -- routes/export.py | grep -E '^[-+]' | grep -vE '^(---|\+\+\+) ' || true)
if [ "$export_changes" = "-@login_required" ]; then
  record PASS "the branch's only change to routes/export.py deletes @login_required"
else
  record FAIL "the branch's only change to routes/export.py deletes @login_required" \
    "changed lines: $(printf '%s' "$export_changes" | tr '\n' '|')"
fi

expect_match 'db\.raw\("SELECT \* FROM reports WHERE id = " \+ report_id\)' "$(sed -n 40p "$repo/reports.py")" "reports.py:40 on the branch is the string-built db.raw call"
expect_match '# input is sanitised upstream' "$(sed -n 39p "$repo/reports.py")" "reports.py:39 carries the misleading comment"
expect_match 're\.fullmatch\(r"\^\[0-9\]\{1,9\}\$", report_id\)' "$(sed -n 12p "$repo/routes/reports.py")" "routes/reports.py:12 checks report_id against ^[0-9]{1,9}\$"
expect_match 'role' "$(sed -n 22p "$repo/invoice_api/auth.py")" "invoice_api/auth.py:22 is the changed line in is_admin"

changed=$(g diff --name-only main...HEAD)
expect_no_match '^tests/' "$changed" "the branch changes no file under tests/"
expect_no_match '^(invoice_api/db\.py|legacy/import\.py|routes/reports\.py)$' "$changed" "db.py, legacy/import.py and routes/reports.py are untouched"
expect_match '^5$' "$(printf '%s\n' "$changed" | grep -c .)" "the branch changes 5 files, so /review takes the small-diff path"
expect_match "'\" \+ batch \+ \"'" "$(g show main:legacy/import.py)" "legacy/import.py on main already builds a query from a string"
expect_no_match 'db\.raw\([^"]' "$(g grep -h 'db\.raw(' main -- '*.py')" "main only ever calls db.raw with a constant string"

payments=$(g diff main...HEAD -- invoice_api/payments.py)
expect_match '^\+ +log\.info\(' "$payments" "the branch adds a catch that logs and continues"
expect_match '^\+ +return 1\.0$' "$payments" "the branch adds a default returned on error"
expect_match '^\+ +for attempt in range\(3\):' "$payments" "the branch adds a retry loop"
expect_match '^\+ +raise$' "$payments" "the branch adds a log-and-re-raise"
expect_match '^\+def refund_invoice\(' "$(g diff main...HEAD -- routes/payments.py)" "the branch adds the refund_invoice route"
expect_match '^\+def _format_cents\(' "$(g diff main...HEAD -- reports.py)" "the branch adds _format_cents"
expect_match 'format_total' "$(g show main:tests/test_reports.py)" "format_total, _format_cents' only caller, is tested on main"

# --- /review: the machine's git config cannot change the fixture or its checks ---
hostile="$work/hostile.gitconfig"
printf '*.md\n' >"$work/hostile.ignore"
printf '[log]\n\tdecorate = short\n[color]\n\tui = always\n[core]\n\texcludesFile = %s\n' \
  "$work/hostile.ignore" >"$hostile"
GIT_CONFIG_GLOBAL="$hostile" bash "$fixture/build.sh" "$work/hostile-repo" >"$work/hostile.out" 2>&1
expect_exit 0 $? "build.sh builds under a global config with excludes, colour and decorate"
expect_match '^OVERVIEW\.md$' "$(git -C "$work/hostile-repo" ls-files)" "build.sh commits OVERVIEW.md whatever the global excludes file says"
expect_match '^[0-9a-f]+ fix\(security\): require login on /export$' \
  "$(GIT_CONFIG_GLOBAL="$hostile" g log -S'@login_required' --oneline main -- routes/export.py)" \
  "the test's git calls ignore a global log.decorate and color.ui"
