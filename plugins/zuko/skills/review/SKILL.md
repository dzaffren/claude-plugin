---
name: review
description: >
  Reviews the built diff for correctness bugs, security holes, and quality
  problems in one pass. Every finding is re-judged blind by a separate
  verifier before it reaches the user. Use after /build, or when the user says
  "review this", "check the code", "is this secure", "any bugs".
disable-model-invocation: true
allowed-tools: Bash(git diff *) Bash(git status *) Bash(git log *) Bash(git stash list)
---

# Review

One pass over the diff covering correctness, security, and quality. Nothing
reaches the user unverified.

Read `${CLAUDE_PLUGIN_ROOT}/references/voice.md`.

## Size the effort

Measure the diff first: `git diff --stat` against the branch point.

| Diff | Shape |
|---|---|
| ≤5 files and ≤300 lines | One `reviewer` agent across all three lenses. One `finding-verifier` per finding. |
| Larger | One `reviewer` per chunk, each running all three lenses. Three `finding-verifier` agents per finding, 2-of-3 majority to keep it. |

Breadth scales with the diff. The verification bar never does.

## The three lenses

Every reviewer runs all three. They are questions, not agents.

**Correctness** — does it do what the acceptance criteria say?
- Every scenario actually covered, including the error ones.
- Off-by-one, null and empty handling, boundary values.
- Concurrency: two of these at once, retries, partial failure.
- What does this catch-block hide? A swallowed error is a silent failure.
- Does the test actually test the thing, or does it pass vacuously?

**Security** — what can an attacker do?
- Injection: SQL, command, template, path traversal.
- Authorization at every new entry point. Not authentication — authorization.
  Can user A reach user B's data?
- Secrets: hardcoded, logged, in error messages, in URLs.
- Untrusted input reaching a sink without validation.
- New dependencies: known CVEs, unmaintained, oddly permissive.
- Tokens and identifiers: random enough, compared safely, expiring.
- Data leaving that should not — PII in logs, fields not stripped.

**Quality** — is this the simple version?
- Does it reinvent something the repo already has?
- An abstraction the acceptance criteria do not demand — the earn-it rule.
- Dead code, commented-out blocks, leftover debug output.
- Drive-by changes to files the plan did not name.
- Comments that no longer match the code.

Use `static-analysis` and `differential-review` (Trail of Bits) when installed.

## UI slices — mechanical checks

For a slice with a web interface, run these as checks, not opinions:

- Colour contrast: body text ≥4.5:1, large text and interactive elements ≥3:1.
- Focus visible on every interactive element; focus order matches visual order.
- `prefers-reduced-motion: reduce` honoured, with a no-motion path that still
  communicates the state change.
- Animations touch `transform` and `opacity` only.
- No layout shift caused by motion.
- Touch targets ≥44×44 CSS px.
- Tier 3 only: the frame rate and bundle budget from the spec, measured.
- `${CLAUDE_PLUGIN_ROOT}/scripts/check-design-drift.sh` passes.

## Reviewer discipline

Put this in every reviewer prompt, verbatim:

> Report correctness, security, and simplification gaps only — not style, not
> preference, not "consider extracting this". Flag anything changed outside
> the spec's named files. You will over-report if you are not careful:
> a finding you cannot trace a concrete failing path for is not a finding.

## Verification

No raw finding reaches the user or gets fixed.

Each finding goes to a `finding-verifier` agent that sees:

- the bare claim, one sentence
- the code
- nothing else

It never sees the finder's reasoning — a verifier shown the reasoning agrees
with it. It defaults to false-positive and confirms only when it has traced a
complete path from an actual input to an actual wrong outcome.

Rejected by default: pre-existing issues the diff did not introduce, anything
a linter would catch, style, hypotheticals with no reachable path, and
findings on lines the diff did not touch.

Small diff: one verifier, must confirm. Large diff: three verifiers with the
reachability / impact / defenses lenses, 2-of-3 to keep.

## Report and fix

Report only what survived. For each:

- what is wrong, in one sentence
- the concrete failing case: these inputs produce this wrong result
- `file:line`
- the fix

Order by severity. Say how many raw findings there were and how many survived
— that number is how the user knows the filter is working.

Nothing survived → say so plainly. A clean review is a real outcome, not a
failure to look hard enough.

Ask before fixing. Then fix, re-run the full suite and the e2e test, and
confirm green.

Capture recurring findings to `docs/learnings/` silently — the third time the
same class of bug appears, it is a lesson, not a coincidence.

Say `/ship` is next.
