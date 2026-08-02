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

1. **Get the diff.** `git diff main...HEAD` (or the repo's default branch).
   Read the spec so you know what the code claims to do.

2. **Review with a fresh eye.** Launch a subagent (general-purpose) with the
   diff and the spec, instructed to find problems, not to praise. Check for:
   - **Correctness** — does each acceptance scenario actually hold? Edge
     cases in the criteria that the code or tests miss?
   - **Reuse** — duplicated logic where an existing helper should be used;
     new abstractions the plan didn't call for.
   - **Simplicity** — dead code, needless config, layers that exist "for
     later", error handling for cases nobody specified.
   - **Consistency** — naming, idiom, and comment density matching each
     touched file; no drive-by reformatting.
   - **Tests** — do they assert behavior (not implementation)? Would they
     fail if the feature broke?

3. **Verify each finding** before acting on it — read the actual code, don't
   trust the reviewer's summary. Drop anything that doesn't hold up.

4. **Fix what's safe.** Apply confirmed fixes that don't change design
   decisions; rerun the project's test command after. Commit as its own
   chunk. Anything that would reopen a design choice goes to the user as a
   one-line flag instead.

5. **Capture lessons automatically** (learn skill). Any finding that will
   recur — a convention the code kept violating, a pattern the diff should
   have reused — becomes a lesson in `docs/learnings/`, written without
   asking. Skip one-off slips.

6. **Report.** Findings fixed, findings flagged, lessons captured, test
   results — actual output, not "should pass". Next step: `/security`.
