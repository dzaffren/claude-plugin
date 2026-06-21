---
name: adversarial-multi-dimension-review-for-skill-changes
description: A multi-dimension adversarial review over a substantive skill-definition change caught real latent bugs before shipping
type: win
captured: 2026-06-21
source: /build — Story 1 self-completing build loop
scope: plugin-general
---

For a substantive change to forge's own skills (e.g. the build loop), run a
multi-dimension adversarial review before shipping: one reviewer per dimension —
correctness vs spec/ADR, no-regression / negative-constraints, internal
consistency, and clarity — and adversarially verify each finding (default to
"not a bug" unless confirmed from the actual files), then fix the confirmed ones.

**Why:** On Story 1 this caught two real latent bugs a single-pass read missed:
(a) `warn`/`manual` was written as if `manual` were a severity, which could let a
blocking `fail`+`manual` code-review finding pass as a non-blocking judgment call;
(b) the "no progress" rule was undefined for round 1, so a literal executor could
stop before fixing anything. Both are shipped-quality bugs in instructions that
get no automated tests.

**What worked:** A four-reviewer workflow (one per dimension) with per-finding
adversarial verification. It flagged both bugs as "optional" (the done-condition
technically backstopped them), but treating them as real and fixing them removed
genuine bug-magnets. Repeat for substantive skill/loop changes — adversarial
review is the main safety net when there is no test harness
([[skill-edits-self-referential-build]]).
