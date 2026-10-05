# /design-system is its own command: Mode 1 of /design moved to its own skill,
# /design keeps one-screen work plus the rename notice, and every pointer and
# the session route name the new command. The skills are prompt text, so this
# checks the text; the headless runs are recorded in docs/specs/design-system.md.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

zuko=$(dirname "$scripts")
root=$(dirname "$(dirname "$zuko")")
system_skill="$zuko/skills/design-system/SKILL.md"
design_skill="$zuko/skills/design/SKILL.md"
notice='/design system is renamed to /design-system. Run /design-system.'

text() { [ -f "$1" ] && cat "$1" || echo "(missing: $1)"; }
frontmatter() { awk 'NR == 1 && /^---$/ { on = 1; next } on && /^---$/ { exit } on { print }' "$1" 2>/dev/null; }

# --- scenario 1: the new skill holds the three pauses and the push ---
ds=$(text "$system_skill")
ds_front=$(frontmatter "$system_skill")
expect_match '^name: design-system$' "$ds_front" "design-system/SKILL.md is named design-system"
expect_match '^disable-model-invocation: false$' "$ds_front" "design-system/SKILL.md allows model invocation"
for phrase in 'set up the design system' 'design tokens' 'extend the design system'; do
  expect_match "$phrase" "$ds_front" "design-system's description names \"$phrase\""
done
for heading in 'Pause A — the brief' 'Pause B — direction test' 'Pause C — the primitive set' 'Push'; do
  expect_match "^# $heading\$" "$ds" "design-system/SKILL.md has '# $heading', one level up"
done
expect_match 'references/craft\.md' "$ds" "design-system/SKILL.md reads craft.md"
expect_match 'references/voice\.md' "$ds" "design-system/SKILL.md reads voice.md"
expect_match 'references/onboard\.md' "$ds" "design-system/SKILL.md runs the onboarding check"
expect_match 'One design system per product' "$ds" "design-system/SKILL.md keeps 'one design system per product'"

# --- scenarios 2 and 3: /design keeps screens and prints the notice for "system" ---
d=$(text "$design_skill")
d_front=$(frontmatter "$design_skill")
if grep -qxF "$notice" <<<"$d"; then
  record PASS "design/SKILL.md carries the rename notice on a line of its own"
else
  record FAIL "design/SKILL.md carries the rename notice on a line of its own" "not found: $notice"
fi
expect_match 'exactly `system`' "$d" "design/SKILL.md applies the notice to an argument of exactly 'system'"
expect_no_match 'Pause [ABC]' "$d" "design/SKILL.md no longer holds the pauses"
expect_no_match '[Dd]esign system' "$d_front" "design's description no longer names the design system"
expect_match 'offer `/design-system` first' "$d" "design/SKILL.md offers /design-system when no system exists"
expect_match '`/design-system` run, not a quiet edit' "$d" "design/SKILL.md sends token changes to a /design-system run"

# --- scenario 4: no stale pointer under plugins/zuko or in README.md ---
# This file is excluded: it has to spell the old command to look for it.
self="$here/test-design-system.sh"
stale=$(
  {
    grep -rnF '/design system' "$zuko" "$root/README.md"
    # The old spelling wrapped across two lines.
    find "$zuko" "$root/README.md" -type f -print0 |
      xargs -0 awk 'FNR == 1 { prev = "" }
                    prev ~ /\/design$/ && $0 ~ /^[[:space:]]*system/ { print FILENAME ":" FNR }
                    { prev = $0 }'
  } 2>/dev/null |
    grep -vF "$self:" |
    grep -vF "$design_skill:$(grep -nxF "$notice" "$design_skill" 2>/dev/null | cut -d: -f1):" || true
)
if [ -z "$stale" ]; then
  record PASS "no file under plugins/zuko or README.md says /design system outside the notice"
else
  record FAIL "no file under plugins/zuko or README.md says /design system outside the notice" \
    "$(tr '\n' '|' <<<"$stale")"
fi

# --- the session route sends design-system setup to the new skill ---
route=$(bash "$scripts/route-to-zuko.sh")
expect_match 'design system setup.*-> zuko:design-system$' "$route" "the route sends design system setup to zuko:design-system"
expect_match '"design the UI".*-> zuko:design$' "$route" "the route keeps \"design the UI\" on zuko:design"
