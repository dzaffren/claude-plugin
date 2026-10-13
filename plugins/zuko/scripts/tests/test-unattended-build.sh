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
expect_no_match 'A command in the plan does not exist' "$deciding" \
  "ledger.md deciding: a missing command is not a choice, so it gets no row"
expect_match '\*\*Belongs in it:\*\* .*- a choice that /build, /review or /ship made alone, as "Deciding alone" says: it changes what the user approved' \
  "$(section "$ledger" "What qualifies")" "ledger.md what qualifies: a choice made alone belongs in the ledger"
expect_match 'Add one row for each choice\. Its Status is `Decided alone`, its Type is `flag`, and Raised at is `build`, `review` or `ship`\. The Answer has three parts and the date:' \
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
expect_match '\| `Decided alone` \| `/build`, `/review` or `/ship` made a choice without the user\. The Answer says what was chosen, the other choice, and how to undo it\. Does not block\. \|' \
  "$(cat "$ledger")" "ledger.md status table: Decided alone does not block"
expect_match 'Do not write it down without asking\. In `/build`, `/review` and `/ship`, a choice made without the user is a `Decided alone` row, as "Deciding alone" says\. In any other stage, any moment a stage would assume something' \
  "$rules" "ledger.md rule 1: /build, /review and /ship write a Decided alone row"
expect_match '`/build` still refuses to start with any Open row\. It prints them and sends the user to `/spec continue \{slice\}`\. It asks nothing\.' \
  "$rules" "ledger.md rule 4: /build sends the user to /spec continue (scenario 5)"
expect_match '\*\*6\. New items can appear at any stage\.\*\* `/build` and `/review` add a `Decided alone` row for each choice they make, and go on\. Only a blocker sets the spec back to `Draft`, at the end of the run\. `/review` finding an unconsidered case adds a row\.' \
  "$rules" "ledger.md rule 6: a choice adds a row; only a blocker sets Draft"
expect_match '`Accepted risk`, `Decided alone` and `Handed to SLICE` rows never count\.' \
  "$rules" "ledger.md rule 7: Decided alone rows never count"
expect_no_match 'walks through each one with the user' "$rules" "ledger.md rule 4: no 'walks through each one with the user'"
expect_no_match 'adds a row and routes back' "$rules" "ledger.md rule 6: no 'adds a row and routes back'"

# --- /build: reads ledger.md, refuses without asking, decides alone ---
build_file="$zuko/skills/build/SKILL.md"
build=$(tr '\n' ' ' <"$build_file" | tr -s ' ')
pointer='as `ledger\.md` › "Deciding alone" says'
expect_match 'Read `\$\{CLAUDE_PLUGIN_ROOT\}/references/voice\.md`, `\$\{CLAUDE_PLUGIN_ROOT\}/references/slicing\.md`, `\$\{CLAUDE_PLUGIN_ROOT\}/references/git-naming\.md` and `\$\{CLAUDE_PLUGIN_ROOT\}/references/ledger\.md`\.' \
  "$build" "build/SKILL.md reads ledger.md"
expect_match 'A spec Status other than `Refined` also means the build does not start\. Print the open rows, then "Run /spec continue \{slice\} to answer them\." Then stop\. Ask nothing, and do not answer a row yourself\.' \
  "$build" "build/SKILL.md gate: prints the rows and sends the user to /spec continue (scenario 5)"
expect_match "Also confirm that the acceptance criteria have not changed since approval\. A command in the plan that does not exist in this repo is not a choice: use the repo.s real command, with no row\." \
  "$build" "build/SKILL.md gate: a missing command uses the real one, with no row"
expect_match 'Do not hand integration to an agent\. Add a `Decided alone` row for each choice that a chunk reports\. Make each choice that a chunk stopped on, then add its row\.' \
  "$build" "build/SKILL.md integrate: a row for each choice a chunk reports"
expect_match "Stay in scope\. When a scenario needs a file that the plan did not name, change it and add a row, $pointer\. A change that no scenario needs is drift\. Do not make it\." \
  "$build" "build/SKILL.md scope: an unnamed file is changed and gets a row (scenario 2)"
expect_match 'anything you did that the plan did not anticipate, and each `Decided alone` row you added\. Set spec Status to `Built`, unless a blocker set it to `Draft`\.' \
  "$build" "build/SKILL.md report: lists each Decided alone row"
expect_match "Do not stop to ask\. Make the choice, edit the spec to match, add a row and go on, $pointer\. Go on also when the choice drops a scenario\." \
  "$(section "$build_file" "When the spec turns out wrong")" "build/SKILL.md: a wrong spec is changed, not stopped on (scenario 1)"
expect_match "A blocker is a thing that you cannot choose around: a missing secret, an account or a paid service\. Do as \`ledger\.md\` › \"Deciding alone\" says\. Build the rest, then set \`Draft\` and add an Open row at the end\. The user answers the row with \`/spec continue \{slice\}\`\." \
  "$(section "$build_file" "When a blocker stops a scenario")" "build/SKILL.md: a blocker ends the run at the end (scenario 4)"
expect_no_match 'work through them with the user' "$build" "build/SKILL.md: no 'work through them with the user'"
expect_no_match 'offer `/poc` instead of guessing' "$build" "build/SKILL.md: the gate no longer offers /poc"
expect_no_match 'or you are drifting \(stop\)' "$build" "build/SKILL.md: no 'or you are drifting (stop)'"
expect_no_match 'Report to the user with a proposal' "$build" "build/SKILL.md: no 'Report to the user with a proposal'"

# --- /review: reads ledger.md, applies both fixes it used to ask about ---
review_file="$zuko/skills/review/SKILL.md"
review=$(tr '\n' ' ' <"$review_file" | tr -s ' ')
expect_match 'Read `\$\{CLAUDE_PLUGIN_ROOT\}/references/voice\.md` and `\$\{CLAUDE_PLUGIN_ROOT\}/references/ledger\.md`\.' \
  "$review" "review/SKILL.md reads ledger.md"
expect_match "A fix that changes something the user approved in the spec \(an interface, a message, the scope\) is applied too\. Edit the spec to match, and add a row, $pointer\." \
  "$review" "review/SKILL.md: a fix that changes the spec is applied (scenario 3)"
expect_match "A Decisions finding is fixed by changing the code to obey the entry\. Add a row, $pointer, with \"supersede the entry through \`/spec\`\" as the other choice\. \`/review\` never edits \`DECISIONS\.md\`\." \
  "$review" "review/SKILL.md: a Decisions finding obeys the entry (scenario 3)"
expect_no_match 'proposed first and waits for a yes' "$review" "review/SKILL.md: no 'proposed first and waits for a yes'"
expect_no_match 'never fixed without asking' "$review" "review/SKILL.md: no 'never fixed without asking'"
expect_no_match 'wait for the user to pick' "$review" "review/SKILL.md: no 'wait for the user to pick'"

# --- the chunk-builder: chooses in its own files, reports each choice ---
chunk=$(tr '\n' ' ' <"$zuko/agents/chunk-builder.md" | tr -s ' ')
expect_match '\*\*The plan is wrong\?\*\* When the choice changes only your own files, make it and build on it\. Report it with the other choice, so that `/build` can add the row\. A choice that needs a file you do not own → stop and report it\. `/build` makes that choice when it integrates\.' \
  "$chunk" "chunk-builder.md: chooses in its own files, stops on another's"
expect_match '- Anything the plan got wrong, and each choice you made: what you chose and the other choice\.' \
  "$chunk" "chunk-builder.md report: each choice and the other choice"
expect_no_match 'Do not improvise around it' "$chunk" "chunk-builder.md: no 'Do not improvise around it'"

# --- the session-start text, read from the hook's real output ---
route=$(bash "$scripts/route-to-zuko.sh" | tr '\n' ' ' | tr -s ' ')
expect_match '2\. Never guess silently\. At a /shape or /spec pause, ask each unknown in the question prompt\. In other stages, write it into the spec.s open-items ledger\. 3\.' \
  "$route" "route-to-zuko.sh rule 2: other stages write into the ledger"
expect_no_match 'ledger as an assumption' "$route" "route-to-zuko.sh: no 'ledger as an assumption'"
