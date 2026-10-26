# At each /spec pause and at the end of /shape, the board shows a gate card.
# The steps that make it are prompt text, so this checks the text: the --gate
# step and the copy step in visual-page.md, the pointers in /spec and /shape,
# and the shorter terminal print at each stop. The card itself has its own
# tests (test-gate.sh). The real publish and the terminal print are checked by
# hand at the next /spec pause (docs/specs/gate-card.md, Test plan).
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

zuko=$(dirname "$scripts")
visual="$zuko/references/visual-page.md"

# One line per section, whitespace squeezed, so a sentence wrapped across
# lines still matches. A "## " line inside a fence ends a section here.
section() { [ -f "$1" ] && awk -v h="## $2" '$0==h{f=1;next} /^## /{f=0} f' "$1" | tr '\n' ' ' | tr -s ' ' || echo "(missing: $1)"; }
flat() { [ -f "$1" ] && tr '\n' ' ' <"$1" | tr -s ' ' || echo "(missing: $1)"; }

board=$(section "$visual" "Idea board")
spec=$(flat "$zuko/skills/spec/SKILL.md")
shape=$(flat "$zuko/skills/shape/SKILL.md")

# --- visual-page.md: the --gate step (scenarios 1, 4) ---
expect_match 'At a stop, add `--gate \{file\}`\.' "$board" "idea board: a stop adds --gate"
expect_match 'A stop is a `/spec` pause or the end of `/shape`\.' "$board" "idea board: names the stops"
expect_match '`/build`, `/review` and `/ship` do not stop, so they do not add `--gate`\. Their board has no card\.' \
  "$board" "idea board: the other stages give no --gate, so no card"

# --- visual-page.md: the copy step, after the publish (scenarios 2, 3, 5; D65) ---
expect_match 'cp docs/specs/\{slice\}\.md docs/specs/\.pages/\{slice\}-last\.md' "$board" "idea board: the copy of a spec"
expect_match 'cp docs/specs/\{idea\}/shape\.md docs/specs/\.pages/\{idea\}-shape-last\.md' "$board" "idea board: the copy of a shape"
expect_match 'At a stop, copy the `--gate` file to `docs/specs/\.pages/`\. Do this also when the publish fails:' "$board" \
  "idea board: the copy is made also when the publish fails"
expect_match 'Copy only after the render\. `render` reads the old copy to show what changed\.' "$board" \
  "idea board: says why the copy comes after the render"
expect_match 'render docs/specs/\{idea\}/shape\.md.*Publish that file with the Artifact tool\..*cp docs/specs/\{slice\}\.md docs/specs/\.pages/\{slice\}-last\.md' \
  "$board" "idea board: the copy step comes after the render and the publish"
expect_no_match 'cp docs/specs/.*Publish that file with the Artifact tool\.' "$board" "idea board: no copy before the publish"

# --- visual-page.md: the terminal line at a stop ---
expect_match 'Board: https://claude\.ai/artifact/… · gate: pause \{n\} of \{slice\}' "$board" "idea board: the Board line names the gate"
expect_match 'At `/shape`, the gate part is `gate: pick the first slice`\.' "$board" "idea board: the gate part at /shape"

# --- /spec: each pointer passes --gate (scenarios 1, 2, 3, 5) ---
pointer='`\$\{CLAUDE_PLUGIN_ROOT\}/references/visual-page\.md` › "Idea board" says'
expect_exit 3 "$(grep -oE -e "For the board at this stop, pass \`--gate docs/specs/\{slice\}\.md\`\. When the spec has a \`\*\*Shape doc:\*\*\` line, republish the idea board, as $pointer\. Pass \`--by \"/spec \{slice\} pause [123]\"\`\." <<<"$spec" | wc -l | tr -d ' ')" \
  "spec/SKILL.md: each of the three pointers passes --gate"

# --- /spec: each "Then stop" prints the shorter terminal (O4, D67) ---
shows='When "Idea board" printed a `Board:` line or a `Board not published:` line, the terminal shows only these, in this order: 1\. That line, as "Idea board" prints it\.'
expect_match "pause 1\"\`\..*That print is for a spec with no board\. $shows 2\. The Flow diagram, in ASCII\. 3\. The question prompt\.[^#]*## Pause 2" \
  "$spec" "spec/SKILL.md pause 1: Board line, the Flow diagram, the prompt"
expect_match "pause 2\"\`\. \*\*Then stop\.\*\* $shows 2\. The Interface map, in ASCII\. 3\. The preview link, when the slice has a preview\. 4\. The question prompt\." \
  "$spec" "spec/SKILL.md pause 2: Board line, the Interface map, the preview link, the prompt"
expect_match "pause 3\"\`\. \*\*Then stop\.\*\* Set Status to \`Refined\`\. $shows 2\. The Approach architecture diagram, in ASCII\." \
  "$spec" "spec/SKILL.md pause 3: Board line, the Approach architecture"

# --- /spec pause 3: the riskiest-choice line stays (O6) ---
expect_match "pause 3\"\`\..*2\. The Approach architecture diagram, in ASCII\. 3\. The spec path, the page link, and the plan's riskiest choice, in one line\. 4\. \`/build\` is next\." \
  "$spec" "spec/SKILL.md pause 3: keeps the spec path and the riskiest choice in one line"
expect_match 'The board lists the drafted entries\. Their full text stays in the spec\.' "$spec" \
  "spec/SKILL.md pause 3: the drafted entries show on the card"

# --- /spec: no board, print as before (Scope Out) ---
expect_match "pause 1\"\`\. \*\*Then stop\.\*\* Show the diagram, the scenarios, the slice test result, and any open items\." \
  "$spec" "spec/SKILL.md pause 1: with no board, prints as before"
expect_match "pause 2\"\`\..*With no board, give the preview link and name which design system the tokens came from\.[^#]*## Pause 3" \
  "$spec" "spec/SKILL.md pause 2: with no board, prints as before"
expect_match "pause 3\"\`\..*With no board, give the spec path, the page link, and the plan's riskiest choice in one line\. Print the ledger, then the drafted entries as \"Decisions to record \(approve with this pause\)\"\. Say \`/build\` is next\.[^#]*## Versioning" \
  "$spec" "spec/SKILL.md pause 3: with no board, prints as before"

# --- /shape: the pointer and the terminal (scenario 4) ---
expect_match "Publish the idea board, as $pointer\. Pass \`--by \"/shape \{idea\}\"\` and \`--gate docs/specs/\{idea\}/shape\.md\`\." \
  "$shape" "shape/SKILL.md step 6: the pointer passes --gate"
expect_match 'The copy is `docs/specs/\.pages/\{idea\}-shape-last\.md`\.' "$shape" "shape/SKILL.md step 6: names the shape's copy"
expect_match 'Then, in the terminal: - The `Board:` line, or the `Board not published:` line\. - The slice map, in ASCII\. - \*\*If the project type is web UI and no design system exists\*\*.* - Ask which slice to spec first' \
  "$shape" "shape/SKILL.md step 6: Board line, slice map, design-system note, then the prompt"
expect_match 'Print nothing else before the prompt\. The board shows the problem, the slices and the open items\.' \
  "$shape" "shape/SKILL.md step 6: nothing else before the prompt"
expect_match 'When "Idea board" printed neither a `Board:` line nor a `Board not published:` line, print the problem in two sentences, the slice list with the diagram, and any open items\.' \
  "$shape" "shape/SKILL.md step 6: with no board, prints as before"
