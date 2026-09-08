---
name: poc
description: >
  A timeboxed spike that answers one risky question with throwaway code. The
  code is deleted; only the answer survives, written back into the spec's
  ledger. Use when a plan rests on an unproven assumption, or the user says
  "spike this", "can we even", "prove it works", "will this be fast enough".
disable-model-invocation: false
---

# POC

One question, one answer, no survivors. This exists so that a plan is never
written on a guess.

Read `${CLAUDE_PLUGIN_ROOT}/references/voice.md`.

## Steps

### 1. State the question

One sentence, with a falsifiable answer. Confirm it with the user before
writing anything.

Good: "Does the Stripe webhook retry with the same idempotency key?"
Bad: "Investigate the payments integration."

If it cannot be phrased as one question with a yes/no or a number as its
answer, it is research, not a spike. Say so.

### 2. Set the box

Agree a timebox out loud — usually 20 to 60 minutes. Also agree what counts as
the answer: a number, a working call, a specific error, a passing script.

### 3. Spike

On a branch named `spike/{question}`, off the current branch.

Rules, all deliberate:

- **No tests.** This code is not staying.
- **No review, no lint, no formatting.** Not staying.
- **No abstraction, no config, no error handling** beyond what proves the
  point. Hardcode everything.
- **No touching production code paths.** A spike that edits real files is not
  a spike.
- Smallest thing that answers the question. Nothing else.

Timebox hit without an answer → stop and say so. "We spent 40 minutes and
still do not know" is a real result, and it changes the plan.

### 4. Answer

Write down:

- The question.
- The answer, plainly.
- The evidence: the output, the number, the error, the code path you saw.
- What this changes about the plan.

### 5. Delete the code

`git checkout` back and delete the spike branch. No exceptions — a spike
branch left alive gets copied into production three weeks later.

The one thing that may survive: a short snippet pasted into the answer, if the
plan needs it as a reference.

### 6. Write it back

Update the spec's ledger row: `unproven` → `Resolved`, with the answer in the
row.

The answer often changes the technical plan. Say exactly what changed, and
route back to `/spec` pause 3 to revise it. Do not leave a plan standing that
the spike just disproved.
