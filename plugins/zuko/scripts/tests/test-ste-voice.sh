# The ASD-STE100 writing rules are prompt text, so this checks the text: the
# section in voice.md, its place between the ban list and the house rules, and
# the README's Voice section. Whether Claude follows the rules is checked by
# hand at the next real stage stop (docs/specs/ste-voice.md, O1).
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

zuko=$(dirname "$scripts")
root=$(dirname "$(dirname "$zuko")")
voice="$zuko/references/voice.md"

# One line per section, whitespace squeezed, so a sentence wrapped across
# lines still matches.
section() { [ -f "$1" ] && awk -v h="## $2" '$0==h{f=1;next} /^## /{f=0} f' "$1" | tr '\n' ' ' | tr -s ' ' || echo "(missing: $1)"; }

ste=$(section "$voice" "Simplified Technical English")

# --- scenario 1: voice.md holds the STE rules ---
expect_match '## Banned outright\|## Simplified Technical English\|## Rules\|' "$(grep '^## ' "$voice" | tr '\n' '|')" \
  "voice.md: the STE section sits between 'Banned outright' and 'Rules'"
expect_match 'ASD-STE100, Issue 9 \(January 2025\)' "$ste" "voice.md STE: names ASD-STE100 Issue 9, January 2025"
expect_match 'It does not use the STE dictionary of approved words\.' "$ste" "voice.md STE: the dictionary is not used"

rules=(
  'An instruction has 20 words or fewer\. A description has 25 words or fewer\.'
  'Write one instruction in each sentence\. Put a condition before the instruction\.'
  'Write an instruction as a command\.'
  'Use the active voice\. In a description, use the passive voice only when the doer is not known\.'
  'Do not make a noun cluster of more than three words\.'
  'Write about one topic in each paragraph\. A paragraph has six sentences or fewer\.'
  'Use an "-ing" form only as a technical noun, or as part of one\.'
  'Do not leave out a verb, a subject or an article to make a sentence shorter\.'
  'Use a vertical list for complex text\.'
)
n=0
for rule in "${rules[@]}"; do
  n=$((n + 1))
  expect_match "$n\. $rule" "$ste" "voice.md STE: rule $n"
done

banned=$(section "$voice" "Banned outright")
expect_match 'leverage' "$banned" "voice.md: the ban list still bans 'leverage'"
expect_match 'Emojis' "$banned" "voice.md: the ban list still bans emojis"
expect_match '2\. \*\*Short sentences\.\*\* If a sentence has two ideas, make it two sentences\. The word limits are in "Simplified Technical English", above\.' \
  "$(section "$voice" "Rules")" "voice.md house rule 2: points to the STE limits"

readme=$(section "$root/README.md" "Voice")
expect_match 'The sentence rules come from ASD-STE100, Simplified Technical English\.' "$readme" \
  "README.md Voice: names ASD-STE100"
expect_match 'An instruction has 20 words or fewer, and a description has 25 or fewer\.' "$readme" \
  "README.md Voice: gives the two limits"

# --- scenario 3: text that is not prose keeps its own format ---
expect_match 'A command, path, number or name in backticks counts as one word\.' "$ste" \
  "voice.md STE: a backticked name counts as one word"
expect_match '\*\*Not prose\.\*\* These keep their own format:' "$ste" "voice.md STE: has the 'Not prose' list"
expect_match '[-] code, commands and paths' "$ste" "voice.md STE: code, commands and paths are not prose"
expect_match "[-] quoted text, copied as it is: the user's words, ticket text, tool output, and a message that a skill gives word for word" "$ste" \
  "voice.md STE: quoted text is copied as it is"
expect_match '[-] headings, table labels, diagram labels and other fragments' "$ste" "voice.md STE: fragments are not prose"
expect_match '[-] commit subjects, which follow `git-naming\.md`' "$ste" "voice.md STE: commit subjects follow git-naming.md"
expect_match '[-] code comments, which match the comments in the file around them' "$ste" \
  "voice.md STE: code comments match the file"
expect_match 'A full sentence follows the rules, also in a table cell or a Gherkin step\.' "$ste" \
  "voice.md STE: a full sentence in a table or a scenario follows the rules"

# --- scenario 4: the project's own writing rules win ---
expect_match "\*\*The project's rules win\.\*\* When the project's CLAUDE\.md sets its own writing rules, follow those rules\. The STE rules fill the gaps\." "$ste" \
  "voice.md STE: the project's CLAUDE.md wins a clash"
