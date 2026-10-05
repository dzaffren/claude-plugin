# scripts/verify-gates.sh and scripts/lib/glossary.py -- a live doc that uses
# a term from the jargon list needs a ## Glossary entry for it.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

work=$(mktemp -d -p "$work")
proj="$work/proj"
mkdir -p "$proj/docs/specs/refund-idea"

gate() {      # gate; sets $gate_out $gate_status
  gate_out=$(CLAUDE_PROJECT_DIR="$proj" bash "$scripts/verify-gates.sh" <<<'{}' 2>&1)
  gate_status=$?
}

problem() {   # problem <file under docs/specs> <term>: the exact line, as a regex
  local line="- $proj/docs/specs/$1 uses $2 with no ## Glossary entry for it."
  printf '^%s$' "$(sed 's/[][\.*^$+?(){}|]/\\&/g' <<<"$line")"
}

spec() {      # spec <file> <status> <body>: a spec that passes every other check
  cat >"$proj/docs/specs/$1" <<SPEC
# ${1%.md}

**Version:** v1 · **Status:** $2 · **Type:** Feature

$3

## Open items

_Never delete this section or its rows._

## Glossary

- **Refund** — money sent back to the buyer.
SPEC
}

# --- Scenario 1: an undefined term fails a live spec, end to end ---

spec refunds.md Draft "The version bump follows semver."
gate
expect_exit 2 "$gate_status" "undefined term: the gate fails"
expect_match '^Spec gate check failed:$' "$gate_out" "undefined term: inside the spec gate block"
expect_match "$(problem refunds.md semver)" "$gate_out" "undefined term: names the doc and the term"

echo '- **Semver** — `MAJOR.MINOR.PATCH` version numbers; MAJOR changes break existing users.' \
  >>"$proj/docs/specs/refunds.md"
gate
expect_exit 0 "$gate_status" "undefined term: adding the entry passes"
expect_match '^$' "$gate_out" "undefined term: a passing gate prints nothing"

# --- Scenario 2: code and paths do not count ---

spec refunds.md Draft 'The bump follows `semver`, and test-e2e-release.sh checks it.

```text
semver: MAJOR.MINOR.PATCH
```'
gate
expect_exit 0 "$gate_status" "code and paths: inline code, a fence and a path pass"

# A plural is still a use of the term; a term inside a longer word is not.
spec refunds.md Refined "Earlier ADRs chose the processor, and the steps are retried idempotently."
gate
expect_exit 2 "$gate_status" "plural: ADRs fails a Refined spec"
expect_match "$(problem refunds.md ADR)" "$gate_out" "plural: names ADR, as the list spells it"
expect_no_match 'uses idempotent ' "$gate_out" "plural: idempotently is not idempotent"

# --- Scenario 3: shipped specs are not re-judged ---

spec refunds.md Shipped "Earlier ADRs chose the processor."
spec release.md Shipped "Each release is an annotated tag."
gate
expect_exit 0 "$gate_status" "shipped: a Shipped spec is skipped"

spec release.md Built "Each release is an annotated tag."
gate
expect_exit 0 "$gate_status" "built: a Built spec is skipped"

spec release.md Refined "Each release is an
annotated tag."
gate
expect_exit 2 "$gate_status" "refined: the same spec at Refined fails"
expect_match "$(problem release.md 'annotated tag')" "$gate_out" "refined: a two-word term across a line break is named"

# --- A shape is a live doc too, and skips the spec-only checks ---

spec release.md Shipped "Each release is an annotated tag."
cat >"$proj/docs/specs/refund-idea/shape.md" <<'SHAPE'
# Refund idea

**Status:** Shaped

## Problem

The lockfile drifts between machines.

## Glossary

- **Refund** — money sent back to the buyer.
SHAPE
gate
expect_exit 2 "$gate_status" "shape: an undefined term fails"
expect_match "$(problem refund-idea/shape.md lockfile)" "$gate_out" "shape: names the shape and the term"
expect_no_match "has Status|no '## Open items'" "$gate_out" "shape: still skips the spec-only checks"

# A doc the helper cannot read fails the gate; it never passes unchecked.
printf '\n## Glossary\n\n- **Lockfile** — caf\351\n' >>"$proj/docs/specs/refund-idea/shape.md"
gate
expect_exit 2 "$gate_status" "unreadable: the gate fails"
expect_match '^- the glossary check could not run: glossary\.py: cannot read .*refund-idea/shape\.md' \
  "$gate_out" "unreadable: says the check could not run, and on which doc"

# --- Scenario 4: the templates carry the section ---

last_heading() {   # last_heading <file>: the last "## " heading in it
  grep '^## ' "$1" | tail -1
}
expect_match '^## Glossary$' "$(last_heading "$scripts/../skills/spec/references/spec-template.md")" \
  "templates: spec-template.md ends with ## Glossary"
expect_match '^## Glossary$' "$(awk '/^```markdown$/ { inside = 1; next } inside && /^```$/ { exit } inside' \
  "$scripts/../skills/shape/SKILL.md" | grep '^## ' | tail -1)" \
  "templates: the shape template ends with ## Glossary"
