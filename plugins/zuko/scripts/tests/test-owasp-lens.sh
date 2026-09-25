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
# tracing code; the longest needed 17.
expect_match '^maxTurns: 20$' "$fv" "finding-verifier.md allows 20 turns"
# A lockfile change is an install-time risk: it needs no caller to count.
expect_match 'exception to rule 1: an `A03:2025 Software Supply Chain Failures`' "$fv" "finding-verifier.md names A03 as the exception to the reachable-path rule"
expect_match 'needs no caller' "$fv" "finding-verifier.md says an A03 lockfile finding needs no caller"
expect_match 'needs no caller' "$ref" "owasp.md says an A03 lockfile change needs no caller"

# --- the skill points at owasp.md and drops the uninstalled plugins ---
sk=$(text "$skill")
expect_match 'references/owasp\.md' "$sk" "review/SKILL.md points at owasp.md"
expect_no_match 'Trail of Bits' "$sk" "review/SKILL.md drops the Trail of Bits line"
expect_no_match 'Injection: SQL, command, template, path traversal' "$sk" "review/SKILL.md drops the old security bullets"
expect_match 'Findings   ' "$sk" "review/SKILL.md's report has the Findings header line"
expect_match 'no category checked' "$sk" "review/SKILL.md says what a diff touching no category prints"

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
