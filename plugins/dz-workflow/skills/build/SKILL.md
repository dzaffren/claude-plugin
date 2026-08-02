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

3. **Disperse or build inline.** Read the plan's **Chunks** section:
   - `Single chunk` (or ≤2 scenarios) → build inline: per scenario, write
     the failing test, implement the smallest change that passes, rerun the
     test command, green before moving on.
   - Multiple chunks → spawn one `feature-builder` agent per chunk, **all in
     parallel in one message**. Each runs in its own isolated git worktree
     and commits there, scenario by scenario. Each agent's prompt contains:
     the spec path, its scenarios, the files it owns (verify the plan's
     ownership is disjoint first — overlap means merge conflicts later;
     merge or serialize overlapping chunks instead), the test command, and
     the repo's lessons from `docs/learnings/INDEX.md`.
   - A chunk that depends on another chunk's output runs after it, not
     beside it.
   In both modes: match each file's existing style; no drive-by refactors —
   if something else is broken, note it in one line and leave it.

4. **Integrate.** When all chunks report back: read each report, then merge
   each chunk's branch into the feature branch in dependency order
   (`git merge <chunk-branch>`; ownership being disjoint, conflicts should
   be rare — resolve any yourself). Run the full test suite on the merged
   result — chunk-green is not integration-green. Fix seams (a helper
   written twice, mismatched conventions at an interface) yourself; a
   blocked or failed chunk gets fixed inline or re-dispatched with the
   corrected prompt. Delete merged chunk branches. Then run any e2e suite
   the repo has, and if the repo has a way to run the app, exercise the
   main flow from the spec once for real.

   While the full suite runs, spawn `quality-reviewer` and
   `security-reviewer` agents in parallel on the branch diff for a first
   pass — their findings seed /quality and /security rather than replacing
   those stages.

5. **Commit as you go** in logical chunks, message style matched to
   `git log`. Check `git status` before each commit for files that shouldn't
   be tracked. Never push.

6. **Report honestly.** If a test fails, show the actual output — don't
   claim done. When everything is green, update the spec's Status to `Built`,
   regenerate its HTML (spec-html skill), and tell the user: what was built,
   the test results, that `/quality` then `/security` are next. End with the
   spec's `file://` link.

7. **Capture lessons automatically** (learn skill). Before finishing, scan
   the session for corrections the user made, blockers that cost real time,
   and conventions discovered in the code. Write each as a lesson in
   `docs/learnings/` without being asked; mention what was captured in one
   line. Nothing worth capturing → capture nothing, say nothing.

## If the plan turns out wrong mid-build

Stop, don't improvise around it. Say in one or two lines what the plan missed
and what the fix implies, and wait — that's a /refine decision, not a build
decision.
