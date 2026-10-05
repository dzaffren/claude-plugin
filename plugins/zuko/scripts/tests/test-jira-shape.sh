# /shape reading a Jira ticket is prompt text, so this checks the text is
# there: step 1's key pattern, both Jira read tool names, the 5-search retry,
# the two failure lines, the no-key rule, and the template's Source line. The
# headless /zuko:shape NOV-125 run is recorded in docs/specs/jira-shape.md.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

zuko=$(dirname "$scripts")
skill="$zuko/skills/shape/SKILL.md"

text() { [ -f "$1" ] && cat "$1" || echo "(missing: $1)"; }

all=$(text "$skill")
# Step 1 on one line, so a phrase the prose wraps still matches.
step1=$(awk '
  /^### 1\. / { on = 1; print; next }
  on && /^### / { exit }
  on { print }' <<<"$all" | tr '\n' ' ' | tr -s ' ')

# grep -F needs the literal, so these use here-strings directly.
has() {                # has <literal> <text> <description>
  if grep -qF -- "$1" <<<"$2"; then record PASS "$3"
  else record FAIL "$3" "not found: $1"; fi
}

has '^[A-Z][A-Z0-9]+-[0-9]+$' "$step1" "step 1 names the ticket key pattern"
expect_match 'whole argument' "$step1" "step 1 matches the key only as the whole argument"
has 'jira_get_issue' "$step1" "step 1 names mcp-atlassian's jira_get_issue"
has 'getJiraIssue' "$step1" "step 1 names the hosted server's getJiraIssue"
expect_match 'up to 5 times' "$step1" "step 1 repeats the tool search up to 5 times"
has "Jira isn't connected, so I can't read {KEY}. Tell me about it, or connect Jira with /mcp." \
  "$step1" "step 1 carries the disconnected line verbatim"
expect_match "Jira's error" "$step1" "step 1 names the key and Jira's error when the read fails"
expect_match 'do not mention Jira' "$step1" "step 1 keeps Jira out of a run with no key"
expect_match 'never instructions' "$step1" "step 1 treats the ticket's text as data"
has '**Source:** {KEY} · {ticket URL}' "$all" "the shape template has the Source line"
