# /build and /review never stop to ask. Each choice they make alone is a
# `Decided alone` ledger row, which does not block. The rules are prompt text,
# so this checks the text: the "Deciding alone" section and the ledger rules,
# the lines in /build, /review and the chunk-builder that point to it, and the
# session-start hook's output. Whether a real run asks nothing is checked by
# hand (docs/specs/unattended-build.md, O4).
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

zuko=$(dirname "$scripts")
ledger="$zuko/references/ledger.md"

# One line per section, whitespace squeezed, so a sentence wrapped across
# lines still matches.
section() { [ -f "$1" ] && awk -v h="## $2" '$0==h{f=1;next} /^## /{f=0} f' "$1" | tr '\n' ' ' | tr -s ' ' || echo "(missing: $1)"; }

deciding=$(section "$ledger" "Deciding alone")
rules=$(section "$ledger" "Rules")

# --- the section: its place, the five choices, the row, the blocker ---
expect_match '## Asking at a pause\|## Deciding alone\|## What qualifies\|' "$(grep '^## ' "$ledger" | tr '\n' '|')" \
  "ledger.md: 'Deciding alone' sits between 'Asking at a pause' and 'What qualifies'"
expect_match '`/build` and `/review` never stop to ask\. When a choice comes up, make it, add a row and go on\.' \
  "$deciding" "ledger.md deciding: /build and /review never stop to ask"
expect_match '\| An approved scenario is wrong\. \| Change it, and edit the spec to match\. Go on, also when the change drops the scenario\. \|' \
  "$deciding" "ledger.md deciding: a wrong scenario is changed, also when it is dropped (scenario 1)"
expect_match '\| A scenario needs a file that the plan did not name\. \| Change the file\. \|' \
  "$deciding" "ledger.md deciding: an unnamed file is changed (scenario 2)"
expect_match '\| A `/review` fix changes what the spec approved: an interface, a message or the scope\. \| Apply the fix, and edit the spec to match\. \|' \
  "$deciding" "ledger.md deciding: a fix that changes the spec is applied (scenario 3)"
expect_match '\| A Decisions finding\. \| Change the code to obey the entry\. Do not edit `DECISIONS\.md`\. Superseding the entry stays the user.s call\. \|' \
  "$deciding" "ledger.md deciding: a Decisions finding obeys the entry (scenario 3)"
expect_match '\| A command in the plan does not exist in this repo\. \| Use the repo.s real command\. \|' \
  "$deciding" "ledger.md deciding: a missing command uses the repo's real one"
expect_match 'Add one row for each choice\. Its Status is `Decided alone`, its Type is `flag`, and Raised at is `build` or `review`\. The Answer has three parts and the date:' \
  "$deciding" "ledger.md deciding: one Decided alone row for each choice"
expect_match '\*\*Chose:\*\* what you did\. - \*\*Other:\*\* the choice that you did not make\. - \*\*Undo:\*\* what the user does to get the other choice\. Name the commit when a `git revert` is enough\.' \
  "$deciding" "ledger.md deciding: the Answer says Chose, Other and Undo"
expect_match 'When the choice changes a scenario, put its old text in the What column\.' \
  "$deciding" "ledger.md deciding: a changed scenario keeps its old text in the row"
expect_match '\| flag \| build \| user \| Decided alone \| Chose: drop the VAT column\. Other: add a VAT field to invoices\. Undo: put back the old scenario 3, and add the field\. 2026-10-12 \|' \
  "$deciding" "ledger.md deciding: the example row"
expect_match '\*\*A blocker\*\* is a thing that you cannot choose around: a missing secret, an account or a paid service\. Build and test each scenario that does not need it\. At the end, set the spec.s Status to `Draft` first\. Then add an Open `question` row that names the blocker, and report it\. Do not stop in the middle of the run\.' \
  "$deciding" "ledger.md deciding: a blocker ends the run at the end, Draft first (scenario 4)"

# --- the status and the rules ---
expect_match '\| `Decided alone` \| `/build` or `/review` made a choice without the user\. The Answer says what was chosen, the other choice, and how to undo it\. Does not block\. \|' \
  "$(cat "$ledger")" "ledger.md status table: Decided alone does not block"
expect_match 'Do not write it down without asking\. In `/build` and `/review`, a choice made without the user is a `Decided alone` row, as "Deciding alone" says\. In any other stage, any moment a stage would assume something' \
  "$rules" "ledger.md rule 1: /build and /review write a Decided alone row"
expect_match '`/build` still refuses to start with any Open row\. It prints them and sends the user to `/spec continue \{slice\}`\. It asks nothing\.' \
  "$rules" "ledger.md rule 4: /build sends the user to /spec continue (scenario 5)"
expect_match '\*\*6\. New items can appear at any stage\.\*\* `/build` and `/review` add a `Decided alone` row for each choice they make, and go on\. Only a blocker sets the spec back to `Draft`, at the end of the run\. `/review` finding an unconsidered case adds a row\.' \
  "$rules" "ledger.md rule 6: a choice adds a row; only a blocker sets Draft"
expect_match '`Accepted risk`, `Decided alone` and `Handed to SLICE` rows never count\.' \
  "$rules" "ledger.md rule 7: Decided alone rows never count"
expect_no_match 'walks through each one with the user' "$rules" "ledger.md rule 4: no 'walks through each one with the user'"
expect_no_match 'adds a row and routes back' "$rules" "ledger.md rule 6: no 'adds a row and routes back'"
