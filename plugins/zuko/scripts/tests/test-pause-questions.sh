# At a /spec or /shape pause, every unknown is asked in the question prompt.
# The rules are prompt text, so this checks the text: the "Asking at a pause"
# section and rules 1 and 4 in ledger.md, the lines in /spec and /shape that
# point to it, and the session-start hook's output. Whether Claude asks at a
# real pause is checked by hand (docs/specs/pause-questions.md, O6).
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

zuko=$(dirname "$scripts")
ledger="$zuko/references/ledger.md"

# One line per section, whitespace squeezed, so a sentence wrapped across
# lines still matches.
section() { [ -f "$1" ] && awk -v h="## $2" '$0==h{f=1;next} /^## /{f=0} f' "$1" | tr '\n' ' ' | tr -s ' ' || echo "(missing: $1)"; }

asking=$(section "$ledger" "Asking at a pause")
rules=$(section "$ledger" "Rules")

# --- the section: its place, and the rules for asking (scenarios 1 to 5) ---
expect_match '## Rules\|## Asking at a pause\|## What qualifies\|' "$(grep '^## ' "$ledger" | tr '\n' '|')" \
  "ledger.md: 'Asking at a pause' sits between 'Rules' and 'What qualifies'"
expect_match 'At each pause, `/shape` and `/spec` ask the user every open question and every assumption\. Use the question prompt, the `AskUserQuestion` tool\.' \
  "$asking" "ledger.md asking: every question and assumption goes to the question prompt"
expect_match 'Ask up to four questions in one prompt\. When there are more, use several prompts, one after the other\.' \
  "$asking" "ledger.md asking: up to four in a prompt, several prompts for more"
expect_match 'Put the recommended answer first, and end its label with "\(Recommended\)"\.' \
  "$asking" "ledger.md asking: the recommended answer is first and marked"
expect_match 'For an `unproven` row, put `/poc` first\. Put the recommended answer second\.' \
  "$asking" "ledger.md asking: an unproven row offers /poc first"
expect_match '"Hand to \{slice\}", with a slice from the table\.' "$asking" \
  "ledger.md asking: a shape can hand a question to a later slice"
expect_match 'Write each answer into its row as `Resolved`, `Accepted risk` or, in a shape, `Handed to \{slice\}`\. Add the date\.' \
  "$asking" "ledger.md asking: each answer goes into its row, with the date"
expect_match 'such as "What made you think of this\?", ask it as plain text\.' "$asking" \
  "ledger.md asking: a question with no answer to offer stays plain text"
expect_match 'When no row is Open, the last question approves the pause\.' "$asking" \
  "ledger.md asking: the approval comes only when no row is Open"
expect_match '`/spec` pause 3 has no last question: the user types `/build`, and that approves the plan\.' "$asking" \
  "ledger.md asking: pause 3 ends when the user types /build"
expect_match '\| `/spec` pause 1 \| Approve pause 1 of \{slice\}\? \|' "$asking" "ledger.md asking: pause 1's last question"
expect_match '\| `/spec` pause 2 \| Approve pause 2 of \{slice\}\? \|' "$asking" "ledger.md asking: pause 2's last question"
expect_match '\| `/shape` \| Which slice do we spec first\? \|' "$asking" "ledger.md asking: the shape's last question"
expect_no_match 'Run /build' "$asking" "ledger.md asking: no answer tries to start /build"
expect_match 'In a `claude -p` run, or when the user denies the tool, print the questions as a numbered list\. Put the recommended answer first in each\. Then stop\. Do not write an answer, and leave each row Open\.' \
  "$asking" "ledger.md asking: with no prompt, print the list and stop"
expect_match 'Recommended: No\. A refund stops at the order total\.' "$asking" "ledger.md asking: the no-prompt example"

# --- rules 1 and 4 ---
expect_match '\*\*1\. Never guess silently\.\*\* At a pause in `/shape` or `/spec`, ask each unknown, as "Asking at a pause" says\. Do not write it down without asking\. In any other stage, any moment a stage would assume something' \
  "$rules" "ledger.md rule 1: ask at a pause, write an assumption elsewhere"
expect_match '\*\*4\. Nothing is approved with an Open row\.\*\* No pause of `/shape` or `/spec` is approved while a row is Open, and this includes pauses 1 and 2\. A shape is not `Shaped`' \
  "$rules" "ledger.md rule 4: no pause is approved with an Open row"
