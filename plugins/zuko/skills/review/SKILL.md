---
name: review
description: >
  Reviews the built diff for correctness bugs, security holes, and quality
  problems in one pass. Every finding is re-judged blind by a separate
  verifier before it reaches the user. Use after /build, or when the user says
  "review this", "check the code", "is this secure", "any bugs".
disable-model-invocation: true
allowed-tools: Bash(git diff *) Bash(git show *) Bash(git status *) Bash(git log *) Bash(git stash list)
---

# Review

One pass over the diff covering correctness, security, quality, and the
active decisions. Nothing reaches the user unverified.

Read `${CLAUDE_PLUGIN_ROOT}/references/voice.md`.

If `OVERVIEW.md` is missing at the repo root, or still says Draft, follow
`${CLAUDE_PLUGIN_ROOT}/references/onboard.md` first, then continue.

## Size the effort

Measure the diff first: `git diff --stat` against the branch point.

| Diff                    | Shape                                                                                                                            |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| ≤5 files and ≤300 lines | One `reviewer` agent across all four lenses. One `finding-verifier` per finding.                                                 |
| Larger                  | One `reviewer` per chunk, each running all four lenses. Three `finding-verifier` agents per finding, 2-of-3 majority to keep it. |

Breadth scales with the diff. The verification bar never does.

## The four lenses

Every reviewer runs all four. They are questions, not agents.

**Correctness** — does it do what the acceptance criteria say?

- Every scenario actually covered, including the error ones.
- Off-by-one, null and empty handling, boundary values.
- Concurrency: two of these at once, retries, partial failure.
- What does this catch-block hide? A swallowed error is a silent failure.
- Does the test actually test the thing, or does it pass vacuously?

**Security** — what can an attacker do? Judged against OWASP Top 10:2025 in
`${CLAUDE_PLUGIN_ROOT}/references/owasp.md`.

- The reviewer runs its **Context first** step: finds the repo's own
  defences, and picks the categories this diff can touch. Only those are
  checked. The rest are named in the scope block with a reason.
- Each security finding carries a `CATEGORY` and a `SEVERITY` from the grid.
- **Never a finding** and **Where OWASP wins** hold in every category.

**Quality** — is this the simple version?

- Does it reinvent something the repo already has?
- An abstraction the acceptance criteria do not demand — the earn-it rule.
- Dead code, commented-out blocks, leftover debug output.
- Drive-by changes to files the plan did not name.
- Comments that no longer match the code.

**Decisions** — does it do what an active decision rejected?

- The reviewer reads the active entries with
  `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/decisions.py" active .` — see
  `${CLAUDE_PLUGIN_ROOT}/references/decisions.md`.
- A diff line that does what an active entry rejected is a finding, and its
  claim names the entry: `contradicts D7 (Use Postgres, not SQLite)`.
- The failing case shows the rejected thing running in the product. Named
  only in a test fixture or a comment → not a finding.
- A superseded entry binds nothing.

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

> Report correctness, security, and simplification gaps, and code that
> contradicts an active decision — not style, not preference, not "consider
> extracting this". Flag anything changed outside the spec's named files. You
> will over-report if you are not careful: a finding you cannot trace a
> concrete failing path for is not a finding.

## Verification

No raw finding reaches the user or gets fixed.

Each finding goes to a `finding-verifier` agent that sees:

- the bare claim, one sentence
- its `CATEGORY`, `SEVERITY`, `FILE`, `SYMBOL` and `SNIPPET`
- the code, plus `DECISIONS.md` for a Decisions finding
- nothing else — never the `FAILING CASE`, never the scope block

It never sees the finder's reasoning — a verifier shown the reasoning agrees
with it. It defaults to false-positive and confirms only when it has traced a
complete path from an actual input to an actual wrong outcome.

Rejected by default: pre-existing issues the diff did not introduce, anything
a linter would catch, style, hypotheticals with no reachable path, and
findings on lines the diff did not touch.

Small diff: one verifier, must confirm. Large diff: three verifiers with the
reachability / impact / defenses lenses, 2-of-3 to keep.

A verifier that hits its turn limit is recorded as not confirmed. It is never
resumed with added context — no hint about callers, no description of the
change, nothing the finder knew. A message like that is the finder's reasoning
by another route, and a verifier shown it agrees with it. The verifier runs
`git diff` and `git show` itself to see the change.

A confirmed security finding keeps the lowest `SEVERITY` a confirming verifier
returned, capped at the reported tier. A verifier's tier above the reported
one is ignored.

With several reviewers, the scope block is the union: a category any reviewer
checked is checked.

## Report and fix

Report only what survived, in this layout:

```
Security   checked A01 Broken Access Control, A05 Injection,
           A10 Mishandling of Exceptional Conditions
           not checked: 7 categories, listed at the end
Findings   7 raw, 3 survived

medium · A05:2025 Injection · exporters/ledger.py:31 in export_ledger
  The new query builds SQL from order instead of calling db.run.
  Failing case: GET /export?customer=ACME-01&order=CASE WHEN (SELECT ...) THEN total
    ELSE issued_at END sorts by a secret, one bit per request.
  Fix: db.run with customer as a parameter, and order checked against
    ("issued_at", "total", "customer").

correctness · exporters/ledger.py:52 in write_rows
  ...

Not checked
  A02 no config or deployment file changed
  ...
```

Each finding gives what is wrong in one sentence, the concrete failing case,
`file:line` with its symbol, and the fix. Security findings come first,
critical to low. Then correctness, decisions and quality, in that order.

The `Findings` line says how many raw findings there were and how many
survived — that number is how the user knows the filter is working.

A diff that touches no category prints
`Security   no category checked — the diff changes README.md only`, naming
what it does change. Nothing survived → `Findings   7 raw, 0 survived — clean`.
A clean review is a real outcome, not a failure to look hard enough.

Fix what survived without asking, whatever its severity — verification
already confirmed it, and severity sets the order, not whether it is fixed. One
exception: a fix that changes something the user approved in the spec (an
interface, a message, the scope) is proposed first and waits for a yes. Fix
each finding test-first where a test can catch it, one commit per finding,
then re-run the full suite and the e2e test, and confirm green.

A Decisions finding is never fixed without asking. Offer exactly two fixes —
change the code, or supersede the entry through `/spec` — and wait for the
user to pick. `/review` never edits `DECISIONS.md`.

Capture recurring findings to `docs/learnings/` silently — the third time the
same class of bug appears, it is a lesson, not a coincidence.

Say `/ship` is next.
