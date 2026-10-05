# The ASCII-terminal rule is prompt text, so this checks the text is there:
# the rule in voice.md, and the terminal's place in diagram-set.md. Whether a
# stage stop actually draws ASCII is checked on the next real /spec stop
# (docs/specs/ascii-terminal.md, O1).
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

zuko=$(dirname "$scripts")
voice="$zuko/references/voice.md"

# One line per section, whitespace squeezed, so a sentence wrapped across
# lines still matches.
section() { [ -f "$1" ] && awk -v h="## $2" '$0==h{f=1;next} /^## /{f=0} f' "$1" | tr '\n' ' ' | tr -s ' ' || echo "(missing: $1)"; }

# --- scenario 3: the rule is in voice.md ---
visuals=$(section "$voice" "Visuals over prose")
expect_match 'Diagrams printed to the terminal are ASCII' "$visuals" \
  "voice.md 'Visuals over prose': terminal diagrams are ASCII"
expect_match 'The terminal shows Mermaid as source' "$visuals" \
  "voice.md 'Visuals over prose': says why — the terminal shows Mermaid as source"
expect_match 'Mermaid stays the source of truth in specs, shapes and published pages' "$visuals" \
  "voice.md 'Visuals over prose': Mermaid lives in files and pages"
expect_match 'the ASCII in the reply draws the same diagram' "$visuals" \
  "voice.md 'Visuals over prose': the ASCII draws the same diagram"

# --- scenario 2: no reference claims Mermaid renders in the terminal ---
whole() { [ -f "$1" ] && tr '\n' ' ' <"$1" | tr -s ' ' || echo "(missing: $1)"; }
claim='renders in the terminal|renders there'
for file in "$zuko/../../README.md" "$zuko/references/visual-page.md" "$zuko/references/diagram-set.md"; do
  expect_no_match "$claim" "$(whole "$file")" "$(basename "$file"): no claim that Mermaid renders in the terminal"
done

expect_match 'ASCII in terminal replies' "$(section "$zuko/references/diagram-set.md" "Where they live")" \
  "diagram-set.md 'Where they live': the terminal gets ASCII"
expect_match 'terminal replies draw (it|them|the same diagrams?) in ASCII' "$(whole "$zuko/../../README.md")" \
  "README.md: terminal replies draw ASCII"
