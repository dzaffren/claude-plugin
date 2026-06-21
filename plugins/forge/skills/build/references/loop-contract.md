# Build Loop Contract

The single source of truth for `/forge:build`'s self-completing loop (Phase 4)
and its pre-commit checkpoint (Phase 4.5). Both phases load this file so the
rules cannot drift between them.

The loop's job: after the work is built and merged (Phase 3.5), keep running the
quality gates and fixing what fails until the work is genuinely **done** — then
stop and let a human approve before anything is saved. Right-sized by design: it
**reuses the gates forge already has** and adds only the loop and the checkpoint.

## The five gates

Each round runs all five and classifies every result as blocking or non-blocking:

| Gate              | Skill / agent                   | Blocking signal                             | Non-blocking signal                  |
| ----------------- | ------------------------------- | ------------------------------------------- | ------------------------------------ |
| Build cleanliness | `verifier`                      | `FAIL`                                       | —                                    |
| Requirements met  | the spec's acceptance criteria  | any unmet criterion                         | —                                    |
| End-to-end        | `e2e`                           | `FAIL` (`ERROR` → stop the loop, see below) | `NO_E2E` → skip                      |
| Security          | `security-review`               | `FAIL`                                       | `WARN` → surface at the checkpoint   |
| Code quality      | `code-reviewer` agent           | any `fail`-severity finding                 | `warn` → checkpoint; `info` → ignore |

The loop changes none of these gates — it only orchestrates them. Each keeps its
existing contract and return values.

**Severity vs. fix type (code-reviewer).** `code-reviewer` reports a `severity`
(`info` / `warn` / `fail`) and, separately, a `fix.type` (`auto` / `manual`).
**Only severity decides blocking:** a `fail` finding is blocking whatever its fix
type, a `warn` finding is a non-blocking judgment call, and an `info` finding is
ignored. `fix.type: manual` only means the loop cannot auto-apply a patch for that
finding — it never turns a `fail` into a non-blocker or a `warn` into a blocker.

## "Done"

The loop may declare the work **done** only when ALL of these hold at once:

- `verifier` returns `PASS`, **and**
- every acceptance criterion in the spec is met, **and**
- `e2e` returns `PASS` or `NO_E2E`, **and**
- `security-review` returns `PASS` or `WARN`, **and**
- `code-reviewer` returns no `fail`-severity findings.

Green checks alone are never "done" if any acceptance criterion is unmet. A
`security-review` `WARN` and `code-reviewer` `warn`-severity findings do **not**
block "done" — they are carried to the Phase 4.5 checkpoint as judgment calls.

## The round

1. Run all five gates.
2. If `e2e` returned `ERROR` → **stop** (infrastructure problem; see Bounds).
3. Compute the **blocking-failure set**: every `verifier` FAIL, every unmet
   acceptance criterion, every `e2e` FAIL, every `security-review` FAIL, and every
   `code-reviewer` `fail`-severity finding. (`security-review` `WARN` and
   `code-reviewer` `warn`-severity findings are not blocking; `info` is ignored.)
4. If the set is empty → **done** → go to the Phase 4.5 checkpoint.
5. Otherwise, if there is round budget left **and** the round made progress →
   spawn fix work scoped to exactly the blocking failures, then start the next
   round.
6. Otherwise (cap reached or no progress) → **stop** and surface the blockers.

Fix work is scoped to the blocking failures only — never let a fix round expand
scope or gold-plate beyond what the requirements call for (right-sizing).

## Bounds — the loop always terminates

- **Round cap.** At most **three** fix rounds. Round 1 is the first gate run after
  Phase 3.5.
- **No progress.** A round makes *no progress* when it does **not shrink** the
  blocking-failure set versus the previous round (same or larger set). On a
  no-progress round, stop immediately rather than re-attempting the identical fix.
  Shrinking the set — even by one blocker — counts as progress and the loop
  continues, subject to the round cap. **Round 1 has no previous round, so the
  no-progress test does not apply to it** — when round 1's blocking set is
  non-empty and budget remains, the loop always proceeds to fix work.
- **`e2e` ERROR.** If `e2e` returns `ERROR` (missing dependency, port conflict,
  config error), stop at once and surface it as an infrastructure blocker. Never
  spawn fix work against an `ERROR` — `e2e` does not install dependencies or start
  services, and neither does the loop.

When the loop stops without reaching "done" (cap / no progress / `e2e` ERROR),
write `BLOCKED.md` per `build`'s existing rules, surface exactly what is still
blocking and what was tried, and **save nothing**.

## Phase 4.5 — the pre-commit checkpoint

Owned by the **main `build` session** (worktree feature-builder workers cannot
commit — see `blocker-feature-builder-cannot-commit`). The loop NEVER saves
without explicit human approval, even when every gate is green.

When the loop reaches "done", present the checkpoint in plain language (apply
`${CLAUDE_PLUGIN_ROOT}/references/plain-language.md`):

1. **What was built** — a short, plain-language summary.
2. **Which gates passed** — the five gates and their result.
3. **Judgment calls** — exactly: every `security-review` `WARN`, every
   `code-reviewer` `warn`-severity finding, and any place the build deliberately
   kept things simple to stay right-sized, each with its reason. Hard failures are
   already fixed by now, so the checkpoint is about judgment calls, not unresolved
   breakage.

Then ask for approval via multi-choice
(`${CLAUDE_PLUGIN_ROOT}/references/multi-choice.md`):

```
Build reached the finish line. Checks: <N>/<N> green. <M> judgment call(s) to review.
Choose:
  1. Approve — save the work and continue to ship
  2. Show me each judgment call
  3. Reject — don't save; I'll redirect
Recommended: 1
```

On `1`, proceed to Phase 5 (ship). On `2`, walk the judgment calls one at a time,
then re-ask. On `3` — or no reply, or a redirect — **save nothing** and return
control to the user.

## Safety invariants (never violate)

- **Bounded** — ≤ 3 rounds, early stop on no progress; no unbounded looping.
- **Stop before commit** — never commit, push, or open a PR without checkpoint
  approval.
- **Security FAIL always blocks "done"** — never reach the checkpoint with an
  unresolved `security-review` FAIL; stop and surface it instead.
- **`e2e` ERROR stops** — never auto-fix infrastructure.
- **Main session owns the checkpoint and the commit** — no worktree worker saves.
- **Gates unchanged** — orchestrate the existing gates; never redefine what they
  check or return.
