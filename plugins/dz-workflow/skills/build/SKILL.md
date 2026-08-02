---
name: build
description: >
  Implements an approved, refined spec end to end with tests. Use after
  /refine is approved, or when the user says "build it", "implement the
  spec", "let's code this". Follows the spec's technical plan, writes tests
  for every acceptance scenario, and runs the project's real test commands.
---

# Build

Implement the approved technical plan — nothing more. The spec's acceptance
criteria are the definition of done.

## Steps

1. **Read the spec** including its `## Technical plan`. If there is no
   technical plan, stop and run /refine first — building without one skips
   the design gate.

2. **Branch.** Never work on `main`/`master`. Branch name from the spec name
   (`feat/{name}`, `fix/{name}` — match the repo's existing convention from
   `git log`/branch names).

3. **Work scenario by scenario.** For each acceptance scenario, in order:
   - Write or extend the test that proves it (at the level the test plan
     says — unit, integration, or e2e).
   - Implement the smallest change that makes it pass, following the plan's
     file-by-file changes and reusing the helpers it names.
   - Run the project's real test command (from the technical plan). Green
     before moving on.
   Match each file's existing style, naming, and comment density. No drive-by
   refactors or fixes outside the plan — if something else is broken, note it
   in one line and leave it.

4. **e2e last.** When all scenarios pass in isolation, run the full test
   suite plus any e2e suite the repo has. If the repo has a way to run the
   app, run it and exercise the main flow from the spec once for real.

5. **Commit as you go** in logical chunks, message style matched to
   `git log`. Check `git status` before each commit for files that shouldn't
   be tracked. Never push.

6. **Report honestly.** If a test fails, show the actual output — don't
   claim done. When everything is green, update the spec's Status to `Built`,
   regenerate its HTML (spec-html skill), and tell the user: what was built,
   the test results, that `/quality` then `/security` are next. End with the
   spec's `file://` link.

## If the plan turns out wrong mid-build

Stop, don't improvise around it. Say in one or two lines what the plan missed
and what the fix implies, and wait — that's a /refine decision, not a build
decision.
