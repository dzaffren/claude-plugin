# One walk through the coverage ledger. The two prompts carry the OLD FILES
# and FILES CHECKED contract. Two releases of a scratch invoice-cli repo in a
# row each write docs/security/coverage.md, and pick reads it back. Sourced by
# run.sh, which provides $scripts, $work and the expect_* helpers.

work=$(mktemp -d -p "$work")
release="$scripts/lib/release.py"
fixtures="$scripts/tests/fixtures/coverage-ledger"
agent="$scripts/../agents/pentester.md"
skill="$scripts/../skills/release/SKILL.md"

# 1. The prompts. The pentester checks the old files as it checks the range,
# and lists each file it read and hunted.
agent_text=$(cat "$agent")
agent_flat=$(tr '\n' ' ' <<<"$agent_text" | tr -s ' ')
expect_match 'You are given `RANGE` \([^)]*\), `OLD FILES`' "$agent_flat" "pentester: OLD FILES is given with RANGE"
expect_match 'Check each file in `OLD FILES` as you check a file that the range changes\.' "$agent_flat" "pentester: checks each old file as a range file"
expect_match 'Use the same categories and the same class files as for the range' "$agent_flat" "pentester: an old file gets the range's categories and class files"
expect_match 'List only the files that you read and hunted\.' "$agent_flat" "pentester: FILES CHECKED lists only files it read and hunted"
expect_match '^FILES CHECKED: \{each file you read and hunted, from the range and from OLD FILES, joined with ", "\}$' "$agent_text" "pentester: the SCOPE template has FILES CHECKED"
scope_template=$(awk '/^SCOPE$/ { f = 1 } f && /^```/ { exit } f' "$agent")
expect_match '^FILES CHECKED: ' "$scope_template" "pentester: FILES CHECKED is in the SCOPE template block"
expect_match '^FILES CHECKED: invoice_cli/cli\.py, invoice_cli/importers/bank\.py, uv\.lock$' "$agent_text" "pentester: the SCOPE example has FILES CHECKED"

# The release step picks the old files after the pin check and before the
# dispatch, copies FILES CHECKED into the report, and repeats cut's Coverage
# line.
skill_text=$(cat "$skill")
skill_flat=$(tr '\n' ' ' <<<"$skill_text" | tr -s ' ')
pick='python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" pick <repo-root>'
grep -qF -e "$pick" <<<"$skill_text"
expect_exit 0 "$?" "release skill: runs release.py pick from the plugin"
pin_at=$(grep -n 'check-attack-pin\.sh' "$skill" | head -n 1 | cut -d: -f1)
pick_at=$(grep -nF -e "$pick" "$skill" | head -n 1 | cut -d: -f1)
dispatch_at=$(grep -n 'Dispatch the `zuko:pentester` agent' "$skill" | head -n 1 | cut -d: -f1)
[ -n "$pin_at" ] && [ -n "$pick_at" ] && [ -n "$dispatch_at" ] && [ "$pin_at" -lt "$pick_at" ] && [ "$pick_at" -lt "$dispatch_at" ]
expect_exit 0 "$?" "release skill: pick runs after the pin check and before the dispatch"
expect_match 'Print its lines to the user as they are\.' "$skill_flat" "release skill: prints pick's lines"
expect_match 'When `pick` exits 1, print its refusal' "$skill_flat" "release skill: prints a pick refusal"
expect_match 'Then end before the pentest: nothing is written\.' "$skill_flat" "release skill: a pick refusal stops the release before the pentest"
expect_match 'Dispatch the `zuko:pentester` agent with `RANGE`, `OLD FILES`, `VERSION`' "$skill_flat" "release skill: gives OLD FILES with RANGE"
expect_match '`OLD FILES` is the paths that `pick` printed, joined with `, `, or `none`' "$skill_flat" "release skill: OLD FILES is pick's paths"
not_at=$(grep -n '^   ## Not assessed$' "$skill" | head -n 1 | cut -d: -f1)
checked_at=$(grep -n '^   ## Files checked$' "$skill" | head -n 1 | cut -d: -f1)
[ -n "$not_at" ] && [ -n "$checked_at" ] && [ "$not_at" -lt "$checked_at" ]
expect_exit 0 "$?" "release skill: the report example has Files checked after Not assessed"
files_section=$(awk '/^   ## Files checked$/ { f = 1; next } f && /^   ```$/ { exit } f && NF' "$skill")
expect_match '^   - invoice_cli/[a-z_/]+\.py$' "$files_section" "release skill: the Files checked example has one path in each line"
expect_no_match '^   [^-]' "$files_section" "release skill: the Files checked example holds only - path lines"
expect_match 'Copy each file in the `FILES CHECKED:` line into `## Files checked`, one in each line\.' "$skill_flat" "release skill: copies FILES CHECKED into the report"
expect_match '^              old files: 10 picked, 9 checked$' "$skill_text" "release skill: the summary counts the old files"
needs_line=$(grep -n '^              needs validation: ' "$skill" | head -n 1 | cut -d: -f1)
old_line=$(grep -n '^              old files: ' "$skill" | head -n 1 | cut -d: -f1)
[ -n "$needs_line" ] && [ -n "$old_line" ] && [ "$old_line" -eq $((needs_line + 1)) ]
expect_exit 0 "$?" "release skill: the old files line follows the needs validation line"
expect_match 'writes `docs/security/vX\.Y\.Z/report\.md` and `docs/security/coverage\.md`' "$skill_flat" "release skill: cut writes the coverage ledger"
expect_match 'Step 4 commits exactly the files it changed' "$skill_flat" "release skill: step 4 commits what cut wrote"
expect_match '^  coverage  13 of 148 files checked by a pentest · 135 not checked$' "$skill_text" "release skill: the step 7 report repeats the Coverage line"
