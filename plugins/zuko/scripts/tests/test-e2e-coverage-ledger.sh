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
