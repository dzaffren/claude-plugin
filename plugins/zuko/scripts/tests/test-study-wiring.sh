# The study wiring: the routing row that sends a study request to /study rather
# than the lesson store, and run.sh skipping the live test visibly.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

work=$(mktemp -d)

routing=$(bash "$scripts/route-to-zuko.sh")

expect_match '\-> zuko:study' "$routing" "the routing table has a study row"
expect_match '"teach me X"' "$routing" "the study row carries the teach me phrase"
expect_match '"I want to learn X"' "$routing" "the study row carries the learn phrase"
expect_match 'status, learn and study' "$routing" "the summary line names study"

# "I want to learn Rust" must not land on the lesson store, so the study row has
# to be read before the learn row.
study_line=$(printf '%s\n' "$routing" | grep -n -- '-> zuko:study' | head -1 | cut -d: -f1)
learn_line=$(printf '%s\n' "$routing" | grep -n -- '-> zuko:learn' | head -1 | cut -d: -f1)
if [ -n "$study_line" ] && [ -n "$learn_line" ] && [ "$study_line" -lt "$learn_line" ]; then
  record PASS "the study row sits above the learn row"
else
  record FAIL "the study row sits above the learn row" "study at ${study_line:-none}, learn at ${learn_line:-none}"
fi

# A live test costs money, so a no-name run leaves it out -- but a skip that
# looks like a pass is the failure docs/learnings/gate-scanned-nothing-is-not-a-
# pass.md is about, so the skip has to be on screen.
sandbox=$(mktemp -d "$work/harnessXXXX")
mkdir -p "$sandbox/tests"
cp "$scripts/tests/run.sh" "$sandbox/tests/run.sh"
printf 'expect_exit 0 0 "a free test ran"\n' >"$sandbox/tests/test-free.sh"
printf 'expect_exit 0 1 "a live test ran"\n' >"$sandbox/tests/test-live-demo.sh"

skip_out=$(bash "$sandbox/tests/run.sh" 2>&1)
expect_exit 0 $? "a no-name run passes while the live test is skipped"
expect_match 'live-demo +skipped, costs money: run\.sh live-demo' "$skip_out" "the skip names itself and the command that runs it"
expect_no_match 'a live test ran' "$skip_out" "the skipped live test recorded nothing"
expect_match 'free +1 passed' "$skip_out" "the free test still ran"

named_out=$(bash "$sandbox/tests/run.sh" live-demo 2>&1)
expect_exit 1 $? "a named live run actually runs it"
expect_no_match 'skipped, costs money' "$named_out" "a named run does not print the skip line"

# Every test being a live one means a no-name run scanned nothing. That is an
# error, not a clean sweep.
only=$(mktemp -d "$work/onlyliveXXXX")
mkdir -p "$only/tests"
cp "$scripts/tests/run.sh" "$only/tests/run.sh"
printf 'expect_exit 0 0 "never reached"\n' >"$only/tests/test-live-only.sh"

only_out=$(bash "$only/tests/run.sh" 2>&1)
expect_exit 1 $? "a run where every test was skipped is not a pass"
expect_match 'no tests ran' "$only_out" "it says nothing ran"

rm -rf "$work"
