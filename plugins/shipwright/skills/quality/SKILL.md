---
name: quality
description: >
  Code quality review of the current branch's changes after /build. Use when
  the user says "quality check", "review the code", "check code quality".
  Reviews with fresh eyes against the spec, applies safe fixes, reports the
  rest.
---

# Quality

Review the branch's diff as a skeptical colleague who didn't write it. The
spec's acceptance criteria and technical plan are the yardstick.

## Steps

1. **Size the review.** `git diff --stat main...HEAD` (or the repo's
   default branch). Small diff (≤5 files and ≤300 changed lines) → one
   `quality-reviewer`, one verifier per finding. Larger → one reviewer per
   area of the plan's Chunks section in parallel, three verifiers per
   finding. Breadth scales with the diff; the verification bar never does.
   Read the spec so you know what the code claims to do.

2. **Review with a fresh eye.** Spawn the `quality-reviewer` agent(s) with
   the diff range and the spec path — read-only, and instructed to report
   correctness gaps only, not style. If /build already ran a first-pass
   review, pass those findings in so it verifies rather than rediscovers.

3. **Verify adversarially.** For each finding, spawn `finding-verifier`
   agents (count from step 1; on the three-verifier shape give each a
   different lens: reachability, impact, defenses — all in parallel across
   all findings). Pass each verifier ONLY the bare claim
   (`file:line · category · one-line scenario`) and the diff range — never
   the reviewer's reasoning; a verifier that reads the argument agrees with
   it. A finding survives on TRUE_POSITIVE from the single verifier, or
   2-of-3 on the panel. Drop the rest silently.

4. **Fix what's safe.** When a confirmed finding has a non-obvious cause,
   prove the cause before patching — `/debug` steps 1–2 — rather than fixing
   the symptom. Apply confirmed fixes that don't change design
   decisions; rerun the project's test command after. Commit as its own
   chunk. Anything that would reopen a design choice goes to the user as a
   one-line flag instead.

5. **Capture lessons automatically** (learn skill). Any finding that will
   recur — a convention the code kept violating, a pattern the diff should
   have reused — becomes a lesson in `docs/learnings/`, written without
   asking. Skip one-off slips.

6. **Report.** Findings fixed, findings flagged, how many the verifiers
   killed, lessons captured, test results — actual output, not "should
   pass". Next step: `/security`.
