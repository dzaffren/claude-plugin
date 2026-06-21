# ADR-002: Build-loop gate ownership and the build↔ship handoff

**Status:** Proposed
**Date:** 2026-06-21
**Deciders:** Platform Team

## Context

The Quality-Gated Pipeline epic turns `/forge:build` into a self-completing loop
whose exit condition is that **all** quality gates are green, iterated up to a
bounded number of rounds, with a human approval checkpoint **before** any commit.

Today the gates are split across two skills:

- **`/forge:build` Phase 4** runs three gates in a single limited pass: the
  `verifier` skill, the spec's acceptance criteria, and the `e2e` skill. It
  attempts at most one fix per failing item, then proceeds whether or not
  everything actually passed.
- **`/forge:ship` Steps 0 and 0.5** run the remaining two gates as pre-commit
  gates: the `security-review` skill (PASS/WARN/FAIL) and the `code-reviewer`
  agent (info/warn/fail findings). `build` invokes `ship` in its Phase 5.

So `security-review` and `code-reviewer` run at **commit time, inside ship**,
after `build` has already finished. For the loop, all five gates must run and
pass (or surface as judgment calls) **before** the commit checkpoint, and the
loop must be able to fix-and-recheck against the full set. The current split
makes that impossible without resolving where the gates live.

A second constraint: `/forge:ship` is also used **standalone** for manual ships
that never went through `/forge:build`. Its Steps 0/0.5 gates must keep running
in that path — they cannot simply be deleted.

A third constraint (existing repo learning `win-code-reviewer-gate-before-commit`):
the `code-reviewer` gate is a *blocking* gate walked finding-by-finding before
commit. The loop must preserve that property, not bulk-accept findings.

## Decision

_Proposed._ **The build loop owns the unified gate set as its exit condition;
`ship` gains a "gates already cleared" mode for post-loop invocation.**

- `build`'s Phase 4 becomes the loop and runs **all five gates**: `verifier`,
  acceptance criteria, `e2e`, `security-review`, and `code-reviewer`. It
  collects blocking failures (verifier FAIL, unmet criteria, e2e FAIL,
  security-review FAIL, code-reviewer `fail`), spawns fix work, and re-runs the
  gates — bounded to ~3 rounds, stopping early when a round resolves nothing new.
- "Done" = `verifier` PASS **and** every acceptance criterion met **and** `e2e`
  PASS or NO_E2E **and** `security-review` PASS-or-WARN **and** `code-reviewer`
  has no `fail` findings. WARN-level security findings and `code-reviewer`
  `warn`/`manual` findings do **not** block "done" — they are surfaced at the
  checkpoint as judgment calls.
- A new **Phase 4.5 pre-commit checkpoint** (owned by the main `build` session,
  not the worktree workers) presents a plain-language summary plus judgment
  calls and waits for approval.
- `build`'s Phase 5 then invokes `ship` with a **skip-gates signal**, so `ship`
  does not re-run Steps 0/0.5. `ship` still owns commit, push, and PR.
- Run **standalone**, `ship` runs Steps 0/0.5 exactly as today.

## Options Considered

### Option A: Build loop owns all five gates; ship gains a skip-gates mode (chosen)

The loop runs the full gate set in `build` Phase 4; `ship` Steps 0/0.5 become
conditional on a signal passed by `build`.

| Pros | Cons |
| --- | --- |
| Reuses every existing gate skill/agent unchanged — no new quality machinery (right-sized). | `build` now depends on `security-review` + `code-reviewer` being available (both already have "unavailable → log and continue" fallbacks the loop inherits). |
| One place owns the loop; the checkpoint sits naturally before ship's commit. | `ship` gains one conditional branch (skip-gates), a small added surface. |
| `ship`'s standalone manual-ship safety is fully preserved. | Requires keeping the two gate definitions usable from two callers (already true today). |

### Option B: Keep gates split; wrap build+ship in an outer loop

An outer controller re-invokes `ship`'s gate steps each round.

Rejected: `ship` Steps 0–5 also do commit/push/PR; you cannot re-run its gate
steps repeatedly without entangling commit logic, and a half-run ship has side
effects. Messy and side-effect-prone.

### Option C: New standalone `/forge:loop` skill orchestrating build + gates + ship

Rejected: duplicates `build`'s context-loading, task decomposition, and worktree
orchestration. More surface area for no new capability — the "rocket" the
discovery brief explicitly warned against.

### Option D: Move security-review + code-reviewer permanently out of ship into build

Rejected: breaks `ship`'s standalone path. Manual ships (no `build`) would lose
their security and code-review gates — a safety regression.

## Consequences

- `plugins/forge/skills/build/SKILL.md` — Phase 4 rewritten as the bounded
  gate-loop; new Phase 4.5 checkpoint added; Phase 5 passes the skip-gates signal.
- `plugins/forge/skills/ship/SKILL.md` — Steps 0 and 0.5 become conditional on
  the skip-gates signal; standalone behavior unchanged.
- The checkpoint is owned by the main `build` session — consistent with
  `blocker-feature-builder-cannot-commit` (worktree workers cannot commit).
- `win-code-reviewer-gate-before-commit` is preserved: `code-reviewer` `fail`
  findings block "done" and are walked individually; `warn`/`manual` findings
  surface at the checkpoint rather than being bulk-accepted.
- `e2e` ERROR (infrastructure problem) stops the loop and surfaces a blocker — it
  is never "fixed" by the loop, matching `e2e`'s own constraint.
- No external contract changes; no new dependencies.
