---
name: fix
description: >
  Dedicated bug-fix pipeline: reproduce the bug with a failing test, find the
  root cause (no shortcuts), patch minimally, verify, security-review, ship.
  Use when the user says "fix this bug", "fix it", "there's a bug in X",
  "production is broken", "triage this error", "patch this", or runs
  /forge:fix. Produces two atomic commits — one with the failing test,
  one with the fix — so the PR is bisect-friendly.
---

# Fix — Bug-fix Fast Path

Go from "I see a bug" to "PR open" without PRD ceremony, while enforcing
reproduce-first discipline.

## Step 1 — Capture the bug (multi-choice)

Ask the user:

```
How do you want to describe the bug?
  1. Paste stack trace / error output
  2. Describe reproduction steps
  3. Link a GitHub issue (I'll fetch it via `gh`)
  4. Explain in my own words
Recommended: 1
```

If the user picks `3`, run `gh issue view <number> --json title,body,comments`
and extract the symptom, repro, and any console output.

Capture into a working-memory block:

- **Symptom** — what the user sees go wrong
- **Expected** — what should happen instead
- **Reproduction** — minimal steps, inputs, or failing command

If any of those three is unclear, ask **one** clarifying question. Not more.

## Step 2 — Reproduce with a failing test

Find the appropriate test file (or create one) for the module that owns the
bug. Write the smallest test that exhibits the bug. Keep it tight — one
assertion, concrete inputs, the exact observed failure.

Run the test and confirm it fails with the reported symptom. If the test
passes, the reproduction is wrong — go back to Step 1.

Confirm with the user:

```
Does this failing test reproduce the bug?
  1. Yes — proceed to root-cause investigation
  2. No — let me correct the repro
  3. Show me the test again
Recommended: 1
```

Commit the failing test as a standalone commit **before** the fix — this is
what makes the PR bisect-friendly. Message: `test(<scope>): reproduce <bug>`.

Validate via `bash ${CLAUDE_PLUGIN_ROOT}/skills/ship/scripts/conventional-commit.sh -`
before committing.

## Step 3 — Investigate root cause (always)

**No shortcuts.** Even when the fix looks obvious, surface a hypothesis with
supporting evidence:

- The code path that leads to the failure (file:line references)
- The invariant that is being violated
- Why the current code violates it

Present the hypothesis to the user multi-choice:

```
Root-cause hypothesis:
  <one-paragraph explanation with file:line references>

Choose:
  1. Accepted — proceed to patch
  2. Investigate further — I see a hole in the reasoning
  3. This is a symptom, not a root cause — dig deeper
Recommended: 1
```

On `2` or `3`, continue investigating. Do not patch until the user accepts the
hypothesis.

## Step 4 — Minimal patch

Write the smallest change that makes the failing test pass. No adjacent
refactors, no opportunistic cleanup, no unrelated TODO fixes. If the fix
touches code outside the failing module, surface that explicitly — it may
indicate a deeper issue that belongs in a new PR.

Run the test — it should now pass. Run the full relevant test file — it
should still pass. If anything regresses, go back to Step 3.

## Step 5 — Verifier

Invoke `verifier` on the changed files (format, lint, types, tests). It must
return clean before proceeding.

## Step 6 — Security review

Invoke `security-review` on the uncommitted fix diff.

- **PASS** — proceed.
- **WARN** — show findings, ask the user multi-choice (same pattern as
  `/forge:ship` step 0). `/forge:fix` will not ship until the user decides.
- **FAIL** — abort. Do not commit the fix. Return the findings and let the
  user decide how to proceed (may need to redesign the fix).

## Step 7 — Commit the fix

Stage the patch (and only the patch — the failing-test commit is already on
branch). Commit:

```
fix(<scope>): <what the fix does in imperative mood>
```

Validate the message with `conventional-commit.sh` before committing. Update
`CHANGELOG.md` via `update-changelog.sh fix "<subject>"` if present.

## Step 8 — Hand off to /forge:ship

Invoke `/forge:ship`. It will detect that commits already exist, run its own
security-review gate (which will PASS since we just ran it), push the branch,
and open the PR.

## Outputs

On success:

- Branch with two atomic commits (failing-test + fix)
- Pull request on GitHub with the failing test and the fix side by side
- Changelog entry under `[Unreleased] → Fixed`

On any abort (failed repro, rejected hypothesis, FAIL from security-review),
leave the branch as-is and report the stopping point. Do not auto-rollback —
the user may want to keep the failing test.
