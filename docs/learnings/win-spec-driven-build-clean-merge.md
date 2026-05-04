---
name: spec-driven-build-clean-merge
description: A rigorous /prd → /prd-refine → /build pipeline produced 4 merging-clean sub-tasks with 6/6 acceptance criteria passing first try
type: win
captured: 2026-05-04
source: /build — ship-release-automation feature (PR #6)
---

A `/forge:build` on a rigorous technical spec produced 4 sub-tasks that
merged into the build branch cleanly (SEQUENTIAL 1 → 2 → 3, INDEPENDENT 4),
passed all 22 test-harness assertions on first run, and satisfied all 6
Acceptance Criteria without any Phase 4 retries.

**Why:** The spec was prepared thoroughly before any code: `/forge:prd`
captured business intent, `/forge:prd-refine` added system design with tradeoff
decisions, concrete Gherkin scenarios, and sub-task breakdowns with exact
file paths and exemplar references. That level of detail let each
feature-builder work in isolation without needing to re-derive design
decisions. Ambiguity caught at spec time doesn't reappear as rework at
build time.

**How to apply:** For non-trivial features (single feature and up), invest
in the full pipeline:

1. `/forge:prd` — write business-level requirements first. Don't skip for
   "simple" technical tasks; spec-first thinking surfaces scope gaps
   before they cost you.
2. `/forge:prd-refine` — add the technical sections BEFORE touching code:
   system design with at least 2 tradeoff decisions, Gherkin acceptance
   criteria, sub-task breakdown with size estimates, file-path-level
   implementation sketches (not full code, but enough to anchor each
   sub-task).
3. Sub-task decomposition discipline — label every sub-task
   `INDEPENDENT` or `SEQUENTIAL` explicitly. When sub-tasks share state
   (like a bash array that sub-task 1 sets and sub-task 2 reads), mark
   them SEQUENTIAL even if they touch different lines in the same file.
4. Test harness per sub-task — each feature-builder writes its own
   scratch tests before implementation (TDD red), commits the test in a
   separate commit from the implementation. Sub-tasks stay independently
   verifiable.

**What worked:** The concrete moves that produced the clean merge:

- Spec labeled sub-tasks 1, 2, 3 as SEQUENTIAL (they touched the same
  file `bump-semver.sh` and sub-task 2 consumed a bash array set up in
  sub-task 1). Sub-task 4 was INDEPENDENT (unrelated SKILL.md prose).
- Each sub-task brief passed to `feature-builder` named only the files
  that sub-task needed, the exact acceptance criteria rows from the
  spec's Test Scenarios section, and the exemplar file path (the
  existing `bump-semver.sh` manifest branch as style guide).
- Merges happened immediately after each SEQUENTIAL sub-task completed
  (Phase 3 rules, not deferred to Phase 3.5). That kept each
  feature-builder's branch short-lived and avoided compounding conflicts.
- Total elapsed time: ~20 minutes for 4 sub-tasks + verifier + ship.
