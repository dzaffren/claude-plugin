# The OWASP lens is prompt text, so this checks the text is there: the
# reference's layout, the new finding format in both agents, the skill's
# pointer, and that the seeded-run fixture still applies. The seeded run itself
# is recorded in docs/specs/owasp-lens.md.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

work=$(mktemp -d -p "$work")
zuko=$(dirname "$scripts")
owasp="$zuko/references/owasp.md"
reviewer="$zuko/agents/reviewer.md"
verifier="$zuko/agents/finding-verifier.md"
skill="$zuko/skills/review/SKILL.md"
fixture="$here/fixtures/owasp-lens"

text() { [ -f "$1" ] && cat "$1" || echo "(missing: $1)"; }

# --- references/owasp.md: the four fixed sections ---
ref=$(text "$owasp")
for heading in "Context first" "Severity" "Never a finding" "Where OWASP wins"; do
  expect_match "^## $heading\$" "$ref" "owasp.md has the '## $heading' section"
done

# --- the ten category headings, exactly as top10.owasp.org/2025 names them ---
expected="## A01:2025 Broken Access Control
## A02:2025 Security Misconfiguration
## A03:2025 Software Supply Chain Failures
## A04:2025 Cryptographic Failures
## A05:2025 Injection
## A06:2025 Insecure Design
## A07:2025 Authentication Failures
## A08:2025 Software or Data Integrity Failures
## A09:2025 Security Logging and Alerting Failures
## A10:2025 Mishandling of Exceptional Conditions"
found=$(printf '%s\n' "$ref" | grep -E '^## A[0-9]{2}:2025 ' || true)
if [ "$found" = "$expected" ]; then
  record PASS "owasp.md has the ten 2025 categories, in order, named exactly"
else
  record FAIL "owasp.md has the ten 2025 categories, in order, named exactly" \
    "found: $(printf '%s' "$found" | tr '\n' '|')"
fi

# --- each category section carries its three labelled parts ---
while IFS= read -r heading; do
  section=$(printf '%s\n' "$ref" | awk -v h="$heading" '
    $0 == h { on = 1; next }
    on && /^## / { exit }
    on { print }')
  id=${heading#\#\# }
  id=${id%%:*}
  for part in "**The diff can touch it when:**" "**Check:**" "**Not a finding:**"; do
    if printf '%s\n' "$section" | grep -qF -- "$part"; then
      record PASS "$id has $part"
    else
      record FAIL "$id has $part" "not found in its section"
    fi
  done
done <<<"$expected"

expect_match 'c19afa7' "$ref" "owasp.md names the security-review commit its exclusions come from"

# --- the reviewer reads owasp.md and reports the new fields ---
rv=$(text "$reviewer")
expect_match '\$\{CLAUDE_PLUGIN_ROOT\}/references/owasp\.md' "$rv" "reviewer.md cites owasp.md by the plugin root"
for field in '^SCOPE$' 'CATEGORY:' 'SEVERITY:' 'SYMBOL:' 'SNIPPET:' 'NOT CHECKED:' 'DEFENCES:'; do
  expect_match "$field" "$rv" "reviewer.md's format carries $field"
done
expect_no_match 'Injection: SQL, command, template, path traversal' "$rv" "reviewer.md drops the old security bullets"

# --- the verifier reads its category's section and may only lower severity ---
fv=$(text "$verifier")
expect_match '\$\{CLAUDE_PLUGIN_ROOT\}/references/owasp\.md' "$fv" "finding-verifier.md cites owasp.md by the plugin root"
expect_match 'SEVERITY:' "$fv" "finding-verifier.md's output carries SEVERITY"
expect_match '[Nn]ever (raise|above)' "$fv" "finding-verifier.md says severity is never raised"
# 13 of 18 verifier runs in the first seeded run stopped at 12 turns while
# tracing code; the longest needed 17. Raised to 30 after run 4, where 16
# turn-limit events remained (O12).
expect_match '^maxTurns: 30$' "$fv" "finding-verifier.md allows 30 turns"
# A lockfile change is an install-time risk: it needs no caller to count.
expect_match 'exception to rule 1: an `A03:2025 Software Supply Chain Failures`' "$fv" "finding-verifier.md names A03 as the exception to the reachable-path rule"
expect_match 'needs no caller' "$fv" "finding-verifier.md says an A03 lockfile finding needs no caller"
expect_match 'needs no caller' "$ref" "owasp.md says an A03 lockfile change needs no caller"
# Run 6: the reviewer wrote "login() unchanged" over a deleted failed-login log.
a09=$(printf '%s\n' "$ref" | awk '$0 == "## A09:2025 Security Logging and Alerting Failures" { on = 1; next } on && /^## / { exit } on { print }')
expect_match 'removed \(`-`\) lines of every changed function' "$a09" "owasp.md's A09 reads the removed lines of changed auth and security functions"
expect_match 'even when nothing was added' "$a09" "owasp.md's A09 counts a deleted log call with nothing added"
expect_match 'removed \(`-`\) lines' "$rv" "reviewer.md's context step points at removed lines"
# /review F2: the verifier hard-coded `main`; the skill passes the branch point.
expect_no_match 'main\.\.\.HEAD' "$fv" "finding-verifier.md has no literal main...HEAD"
expect_no_match 'main:' "$fv" "finding-verifier.md has no literal main:"
expect_match 'git diff <BASE>\.\.\.HEAD -- <file>' "$fv" "finding-verifier.md diffs against BASE"
expect_match 'git show <BASE>:<file>' "$fv" "finding-verifier.md reads the base version at BASE"
expect_match '`BASE: <ref or sha>`' "$(text "$skill")" "review/SKILL.md passes BASE to each verifier"
# /review F1: "documentation files such as Markdown" hid permission changes in
# agent and skill files, which are Markdown with frontmatter.
section() {    # section <exact heading>: the lines under it in owasp.md
  printf '%s\n' "$ref" | awk -v h="$1" '$0 == h { on = 1; next } on && /^## / { exit } on { print }'
}
wins=$(section "## Where OWASP wins")
expect_match 'Documentation files \(exclusion 16\) → A02' "$wins" "Where OWASP wins brings permission frontmatter back under A02"
expect_match 'frontmatter that grants tools or permissions' "$wins" "Where OWASP wins names frontmatter that grants tools or permissions"
a02=$(section "## A02:2025 Security Misconfiguration")
expect_match 'frontmatter' "$a02" "A02's check list covers widened permissions in Markdown frontmatter"
# The verifier sees the diff itself; scope-verifier-bash.sh holds it to
# read-only git (D8).
expect_match '^tools: Read, Grep, Glob, Bash$' "$fv" "finding-verifier.md has Bash"
expect_match 'Bash is for `git diff` and `git show` only' "$fv" "finding-verifier.md says what its Bash is for"
# Run 3: the hook blocked 47 grep/find/ls-files calls the verifier's own tools do.
expect_match 'search and list files with Grep and Glob' "$fv" "finding-verifier.md searches with Grep and Glob, not Bash"

# --- the skill points at owasp.md and drops the uninstalled plugins ---
sk=$(text "$skill")
expect_match 'references/owasp\.md' "$sk" "review/SKILL.md points at owasp.md"
expect_no_match 'Trail of Bits' "$sk" "review/SKILL.md drops the Trail of Bits line"
expect_no_match 'Injection: SQL, command, template, path traversal' "$sk" "review/SKILL.md drops the old security bullets"
expect_match 'Findings   ' "$sk" "review/SKILL.md's report has the Findings header line"
expect_match 'no category checked' "$sk" "review/SKILL.md says what a diff touching no category prints"
# Run 3: -p denied 53 verifier `git show` calls the skill's allowed-tools did not grant.
expect_match '^allowed-tools: .*Bash\(git show \*\)' "$sk" "review/SKILL.md's allowed-tools grants git show"
# Run 2's resumes leaked the finder's context into verifiers that ran out of turns.
expect_match 'turn limit is recorded as not confirmed' "$sk" "review/SKILL.md records a verifier out of turns as not confirmed"
expect_match 'resumed with added context' "$sk" "review/SKILL.md never resumes a verifier with added context"

# --- the seeded diff makes its A10 fail-open reachable from a route ---
bp=$(text "$fixture/branch.patch")
expect_match '^\+.*if not is_admin\(' "$bp" "branch.patch calls is_admin() from a route"

# --- the seeded-run fixture still applies to its base ---
for patch in branch readme; do
  repo="$work/$patch"
  cp -R "$fixture/base" "$repo"
  git -C "$repo" init -q -b main
  git -C "$repo" add -A
  git -C "$repo" -c user.email=t@example.com -c user.name=Tester commit -q -m "feat: invoice csv export"
  git -C "$repo" apply --check "$fixture/$patch.patch" 2>"$work/$patch.err"
  expect_exit 0 $? "$patch.patch applies to fixtures/owasp-lens/base"
done
