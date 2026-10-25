# Each idea's board is republished by five stages. The steps are prompt text,
# so this checks the text: the "Idea board" section in visual-page.md, and
# the line in each stage that points to it. The script that draws the board
# has its own tests (test-board.sh). The real publish is checked by hand at a
# /spec pause (docs/specs/idea-board.md, Test plan).
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

zuko=$(dirname "$scripts")
visual="$zuko/references/visual-page.md"

# One line per section, whitespace squeezed, so a sentence wrapped across
# lines still matches. A "## " line inside a fence ends a section here, so a
# line under a fenced example is checked against the whole file instead.
section() { [ -f "$1" ] && awk -v h="## $2" '$0==h{f=1;next} /^## /{f=0} f' "$1" | tr '\n' ' ' | tr -s ' ' || echo "(missing: $1)"; }
flat() { [ -f "$1" ] && tr '\n' ' ' <"$1" | tr -s ' ' || echo "(missing: $1)"; }

board=$(section "$visual" "Idea board")
hublink=$(section "$visual" "Link back to the hub")

# --- the section and its place ---
expect_match '\|## Link back to the hub\|## Idea board\|## Hub page\|' "|$(grep '^## ' "$visual" | tr '\n' '|')" \
  "visual-page.md: 'Idea board' sits between 'Link back to the hub' and 'Hub page'"

# --- which stages republish, and which do not (scenarios 1, 2, 3, 5; O5) ---
expect_match '`/shape`, at step 6\.' "$board" "idea board: /shape publishes at step 6"
expect_match '`/spec`, at each pause\.' "$board" "idea board: /spec republishes at each pause"
expect_match '`/build`, at its report\.' "$board" "idea board: /build republishes at its report"
expect_match '`/review`, after it writes the `## Review` section\.' "$board" "idea board: /review republishes after the Review section"
expect_match '`/ship`, after the hub page\.' "$board" "idea board: /ship republishes after the hub page"
expect_match '`/release` does not republish the board\.' "$board" "idea board: /release does not republish"

# --- which idea (scenario 4) ---
expect_match 'Each other stage reads the `\*\*Shape doc:\*\*` line of its spec\.' "$board" "idea board: the stages find the idea from the Shape doc line"
expect_match 'When the spec has no `\*\*Shape doc:\*\*` line, skip the board\. Say nothing about it\.' "$board" \
  "idea board: no Shape doc line, no board and no message"

# --- made by the script, not by hand ---
expect_match 'Do not load `artifact-design` for the board\.' "$board" "idea board: artifact-design is not loaded"
expect_match 'Do not edit the HTML\.' "$board" "idea board: the HTML is not edited by hand"

# --- the steps (scenarios 1 and 2) ---
expect_match 'python3 "\$\{CLAUDE_PLUGIN_ROOT\}/scripts/lib/board\.py" render docs/specs/\{idea\}/shape\.md --by "\{stage\} \{slice\}"' \
  "$board" "idea board: the render command"
expect_match '`--by "/spec idea-board pause 1"`' "$board" "idea board: an example of --by"
expect_match 'Write the output to `docs/specs/\.pages/\{idea\}-board\.html`\.' "$board" "idea board: the file path"
expect_match 'Publish that file with the Artifact tool\. Use the same file path each time, so the URL stays the same\.' \
  "$board" "idea board: same file path, same URL"
expect_match 'Give an icon on the first publish only\.' "$board" "idea board: the icon on the first publish only"
expect_match 'After the first publish, add `\*\*Board:\*\* \{url\}` to `shape\.md`, on its own line under the `\*\*Project type:\*\*` line\. Do not change that line after\.' \
  "$board" "idea board: the Board line goes into shape.md once"
expect_match 'Board: https://claude\.ai/artifact/…' "$board" "idea board: the terminal line"

# --- the script fails ---
expect_match '`render` exits 2 when it cannot read the shape, or when the shape has no `## Slices` table\. Print its message as one line\. Then go on with the stage\.' \
  "$board" "idea board: render exit 2 is one line, and the stage goes on"

# --- the publish fails (scenario 5; O4, O9, O11) ---
expect_match 'When the publish fails, the stage goes on\.' "$board" "idea board: a failed publish does not stop the stage"
expect_match 'curl -s -o /dev/null http://127\.0\.0\.1:4750/' "$board" "idea board: the server check"
expect_match 'python3 "\$\{CLAUDE_PLUGIN_ROOT\}/scripts/lib/board\.py" serve docs/specs/\.pages' "$board" "idea board: the serve command"
expect_match 'Board not published: \{error\}\. Local board: http://127\.0\.0\.1:4750/\{idea\}-board\.html' "$board" \
  "idea board: the localhost line"
expect_match 'Board not published: \{error\}\. Port 4750 is in use, so open the file: \{absolute path\}' "$board" \
  "idea board: the port-in-use line"
expect_match 'Leave the server running after the stage ends\.' "$board" "idea board: the server stays up"
expect_match 'The next stage tries the publish again\.' "$board" "idea board: the next stage tries again"

# --- each spec page links to its board (O7) ---
expect_match 'Part of \{idea\} — board: \{url\}' "$hublink" "visual-page link back: the board line on a spec page"

# --- the stages point to the section ---
pointer='`\$\{CLAUDE_PLUGIN_ROOT\}/references/visual-page\.md` › "Idea board" says'
shape=$(flat "$zuko/skills/shape/SKILL.md")
spec=$(flat "$zuko/skills/spec/SKILL.md")
build=$(flat "$zuko/skills/build/SKILL.md")
review=$(flat "$zuko/skills/review/SKILL.md")
ship=$(flat "$zuko/skills/ship/SKILL.md")
release=$(flat "$zuko/skills/release/SKILL.md")

expect_match "Publish the idea board, as $pointer\..*Then, in the terminal:" "$shape" "shape/SKILL.md step 6: publishes the board before the terminal list"
expect_match '- The `Board:` line\.' "$shape" "shape/SKILL.md step 6: the terminal list has the Board line"

expect_exit 3 "$(grep -oE -e "When the spec has a \`\*\*Shape doc:\*\*\` line, republish the idea board, as $pointer\. Pass \`--by \"/spec \{slice\} pause [123]\"\`\. \*\*Then stop\.\*\*" <<<"$spec" | wc -l | tr -d ' ')" \
  "spec/SKILL.md: each of the three pauses republishes the board just before 'Then stop'"

expect_match "Set spec Status to \`Built\`, unless a blocker set it to \`Draft\`\. Then, when the spec has a \`\*\*Shape doc:\*\*\` line, republish the idea board, as $pointer\." \
  "$build" "build/SKILL.md step 7: republishes the board after Status is Built"

expect_match "Commit the spec as \`docs\(spec\): record the review of \{slice\}\`\. Then, when the spec has a \`\*\*Shape doc:\*\*\` line, republish the idea board, as $pointer\." \
  "$review" "review/SKILL.md: republishes the board after the Review section is committed"

expect_match "Republish the hub page from .*- When the spec has a \`\*\*Shape doc:\*\*\` line, republish the idea board, as $pointer\..*render-readme-block\.sh --write" \
  "$ship" "ship/SKILL.md: republishes the board right after the hub page"
expect_match 'A new `\*\*Board:\*\*` line in the shape goes in the commit below\.' "$ship" "ship/SKILL.md: a new Board line is committed with the refresh"

expect_no_match '"Idea board"' "$release" "release/SKILL.md: does not republish the board"
