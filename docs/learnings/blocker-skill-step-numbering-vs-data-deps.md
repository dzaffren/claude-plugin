---
name: skill-step-numbering-vs-data-deps
description: Workflow skills with numbered steps must have producer steps run before consumers
type: blocker
captured: 2026-05-04
source: /ship — PR #3 code-review gate (self-caught)
---

When authoring a skill whose steps produce and consume data across step
boundaries (e.g. one step calls an agent and another step reads its output),
the producer step must execute before every consumer. Verify the numbering
and ordering before shipping — the code-reviewer agent flagged this twice in
one session on the /ship skill (Step 6.5 consumed Step 7 output; Step 8
consumed Step 7 output with an implicit contract Step 7 did not document).

**Why:** Steps execute in numeric order. A consumer placed before its
producer reads stale or empty state — silent failure mode. The original
Step 6.5 feature "silently skipped" on the primary /build → /ship path
because it ran before the capture it was supposed to sync.

**How to apply:** When adding a step to any numbered workflow skill:

1. List every piece of data the new step reads. For each, identify the
   producing step.
2. Confirm the producing step's number is strictly less than the consumer's.
3. If the producer does not explicitly return / record the value, add an
   explicit contract line to the producer ("Record X into Y; step Z
   consumes it"). Implicit contracts rot.
4. Prefer placing sync-type steps (append to log, update index, post
   report) as the LAST step in a pipeline so every producer has already run.

**What was tried:** Originally placed Step 6.5 after Step 6 (Report) but
before Step 7 (Capture), assuming "6.5 is close to 7 so it reads 7's
output". Wrong — numeric order is what matters, not textual adjacency. Fixed
by renaming to Step 8 and placing after Step 7. Caught by the new
code-reviewer gate before ship.
