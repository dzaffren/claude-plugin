---
name: code-reviewer-gate-before-commit
description: The /ship Step 0.5 code-review gate caught two fail-severity bugs on day one
type: win
captured: 2026-05-04
source: /ship — PR #3 (meta: the gate's first run)
---

Having `/ship` invoke the `code-reviewer` agent on the uncommitted diff
before commit is worth keeping. It paid for itself on its first run by
finding two FAIL-severity bugs in unreleased code that had already
passed an author read-through and a plan/approval cycle.

**Why:** Human / assistant read-throughs consistently miss:

- Data-dependency ordering bugs (Step 6.5 consumes Step 7 output but
  runs before it).
- Data-loss footguns in "harmless-looking" rollback paths
  (`git checkout -- <files>` on a dirty tree).

An LLM agent with a narrow, rubric-driven review focus catches those
more reliably than a final skim. The gate blocks ship on FAIL, which
is the behavior that actually prevents the bug from reaching `main`.

**How to apply:** Keep Step 0.5 in `/ship` as a blocking gate. Resist
the urge to downgrade FAIL findings to WARN without genuine
investigation — our first two were real. When the `code-reviewer`
agent flags something, walk through each finding per the multi-choice
flow rather than bulk-accepting. Trust the gate over a fast read.

**What worked:** The concrete moves:

1. Authored a dedicated `code-reviewer` agent at
   `plugins/forge/agents/code-reviewer.md` with a narrow rubric
   (dead code, obvious bugs, style drift, missing tests, readability)
   and a strict JSON output contract.
2. Wired it into `/ship` as Step 0.5, between security review (Step 0)
   and state detection (Step 1) — early enough to prevent wasted
   commits, late enough to see the full diff.
3. Kept the agent SEPARATE from the existing scope-only `reviewer` agent
   used inside `/build`. Different purpose, different rubric, different
   output — no overloading.
4. On FAIL, the gate asks "walk me through" or "abort" — no
   auto-continue. That friction is the point.
