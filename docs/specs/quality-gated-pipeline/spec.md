# Quality-Gated Pipeline — Overview

**Discovery Brief:** docs/discovery/quality-gated-pipeline/brief.md

## Summary

This epic turns forge into a quality-gated pipeline that does more per prompt at
a high, trustworthy quality bar. The planning stages (discovery → prd →
prd-refine) stress-test their own output and surface only the decisions that
genuinely need a human — in plain language. The build stage becomes a
self-completing loop that builds, checks, and fixes its own work until every
quality check passes and the agreed requirements are met, then stops and asks for
approval before saving anything. It is for forge users — makers ranging from
non-technical product owners to solo developers — who today must babysit the
pipeline by hand.

## Background & Context

**Current state:**

- The pipeline runs in stages: discovery → prd → prd-refine → build → ship. Each
  stage produces an artifact the next stage consumes.
- To raise quality, the user manually runs a separate "grilling" stress-test
  after each planning stage, then reads through it.
- The build stage makes a single, limited pass: it runs its checks once and
  attempts at most one fix per unmet item, then proceeds. It does not keep
  iterating until everything is actually green.
- After a build, the user manually re-runs review and fixes, round after round,
  until the work is genuinely done.
- Questions, answers, and recommendations are sometimes too technical to follow,
  and recommendations rarely show the reasoning behind them — so a non-technical
  user tends to accept them on faith, with no easy way to tell if a suggestion is
  over-built for the task.

**Problem:**

- The user carries the quality effort by hand at every stage. This is the single
  biggest tax on the workflow and it happens on every feature.
- Without a clear, trustworthy "finish line," the build never self-completes, and
  the user can't be confident that "it ran" means "it's done and right-sized."
- Technical, unexplained output erodes trust: the user can't easily judge whether
  a recommendation is correct, or whether forge has quietly over-engineered the
  solution.

## Goals

- Cut manual quality effort to near zero: no manually invoking the grilling step
  at each planning stage, and no manually re-running review/fix after a build.
- Make the build stage self-complete to a trustworthy finish line — all quality
  checks pass **and** the agreed requirements are met — while keeping a human
  approval checkpoint before anything is saved.
- Make every question, answer, and recommendation understandable, with a stated
  reason behind it and an option to see the technical detail on demand.
- Keep everything right-sized: reuse the quality checks forge already has rather
  than inventing new ones, and actively avoid over-engineering (a bike when a
  bike was asked for, not a rocket).

## Non-Goals

- A fully autonomous run with no human checkpoints (discovery → ship untouched by
  the user). The planning stages stay human-led, and the build stage always stops
  before saving for approval. Full hands-off autonomy is explicitly deferred.
- Inventing a brand-new set of quality standards. The pipeline reuses forge's
  existing checks as its quality bar.
- Changing what the existing individual checks evaluate. This epic orchestrates
  and presents them; it does not redefine them.

## Story Index

| Ticket | Story                                    | Spec                                                                       | Type        | Status      | Dependencies                  |
| ------ | ---------------------------------------- | -------------------------------------------------------------------------- | ----------- | ----------- | ----------------------------- |
| TBD    | Self-completing build loop               | [spec-self-completing-build-loop.md](spec-self-completing-build-loop.md)   | User-facing | Not Started | —                             |
| TBD    | Self-grilling planning stages            | [spec-self-grilling-planning-stages.md](spec-self-grilling-planning-stages.md) | User-facing | Not Started | —                             |
| TBD    | Plain-language & trust layer             | [spec-plain-language-trust-layer.md](spec-plain-language-trust-layer.md)   | User-facing | Not Started | Soft: Stories 1 & 2 (for full coverage) |

## Shared Business Rules

- **SR1 — Humans lead the planning stages.** Discovery, prd, and prd-refine always
  keep the user in control. The self-grill assists by critiquing the draft and
  surfacing genuine decisions, but the user makes every call at these stages.
- **SR2 — The build stage is the only autonomous stage, and it always stops before
  saving.** It runs its loop on its own but never commits work without showing the
  user a plain summary and getting approval.
- **SR3 — "Done" means checks pass AND requirements are met.** For the build loop,
  the finish line is: every quality check is green **and** the agreed acceptance
  criteria are satisfied. Green checks alone are not "done" if the requirements
  aren't met.
- **SR4 — Bounded effort, never silent failure.** The build loop tries a small
  number of fix rounds (around three) and stops early if a round resolves nothing
  new. When it cannot reach "done," it stops and shows exactly what is blocking —
  it never loops indefinitely and never quietly gives up.
- **SR5 — Reuse the existing quality bar.** The pipeline uses forge's existing
  checks rather than inventing a parallel set of standards.
- **SR6 — Plain language with a reason, depth on demand.** Every question, answer,
  and recommendation is in plain language and states the reason behind it, with an
  option to reveal the technical detail when the user wants it.
- **SR7 — Right-sizing is explicit.** Recommendations and builds are scaled to the
  task. When the pipeline deliberately keeps something simple, it says so, so the
  user can see it isn't over-building.

## User Journey Map

1. **Idea → discovery** — The user brings a fuzzy idea. The discovery stage drafts
   a brief, stress-tests its own draft, and asks only the few decisions that
   genuinely need a human — in plain language, each with a reason. _(Stories:
   Self-grilling planning stages, Plain-language & trust layer)_
2. **Requirements → prd** — The prd stage drafts requirements, self-grills them for
   gaps and contradictions, and surfaces only the real product decisions. _(Stories:
   Self-grilling planning stages, Plain-language & trust layer)_
3. **Technical detail → prd-refine** — The prd-refine stage adds technical depth,
   self-grills it, and surfaces only what the user must weigh in on — in plain
   language, with "show technical detail" available. _(Stories: Self-grilling
   planning stages, Plain-language & trust layer)_
4. **Build → self-completing loop** — The build stage builds, runs every quality
   check, fixes what failed, and repeats until done or it hits the safe limit.
   _(Stories: Self-completing build loop, Plain-language & trust layer)_
5. **Approve → save** — The loop stops before saving and shows a plain summary of
   what it built, which checks passed, and any judgment calls it made. The user
   approves, and only then does forge save the work and continue to ship. _(Stories:
   Self-completing build loop, Plain-language & trust layer)_

## Success Metrics

- **Manual quality steps per feature drop to near zero** — the user no longer
  separately runs the grilling step at each planning stage, nor manually re-runs
  review/fix after a build. The only human touchpoints are genuine decisions plus
  one pre-save approval.
- **Builds self-complete more often** — the share of builds that reach "all checks
  green and requirements met" without manual iteration increases noticeably
  compared to today's single-pass behavior.
- **The user can explain every recommendation** — because the reason is always
  shown, the user can say why a suggestion was made, and "I don't understand this"
  moments fall.
- **No over-engineering in review** — builds are sized to the task; reviewers don't
  flag gold-plating, and the pipeline surfaces where it deliberately kept things
  simple.

## Dependencies

- **Reuses existing forge stages and checks** — product-discovery, prd, prd-refine,
  build, ship, the grilling stress-test, and the existing quality checks
  (security, code quality, tests, end-to-end). This epic orchestrates and presents
  them; it does not rebuild them.
- **Validation prerequisite** — before building the Self-completing build loop, run
  the one-hour hand-run experiment from the discovery brief to confirm that "all
  checks green" really equals "genuinely done and right-sized." If it does not, the
  loop's finish line must include the spec's acceptance criteria as an explicit
  check before automation proceeds.

## Rollout Strategy

- **Order:** Self-completing build loop first (highest value, the missing piece) →
  Self-grilling planning stages → Plain-language & trust layer last, so it also
  standardizes the output of the new loop and the self-grills.
- **Validate before building Story 1:** run the discovery brief's one-hour
  hand-run experiment to confirm the finish line is trustworthy.
- **Activation caveat:** changes to a stage take effect the next time the user
  starts a session, not in the middle of the current one. Communicate this so users
  aren't surprised when an in-progress session behaves the old way.

## Open Questions

- [x] ~~How hard should the build loop try before stopping for help?~~ —
  **Resolved:** A few fix rounds (around three), stopping early if a round resolves
  nothing new; then stop and surface what is blocking. (SR4)
- [x] ~~What should the loop show at the pre-save checkpoint?~~ — **Resolved:** A
  plain-language summary of what it built and which checks passed, plus any judgment
  calls (unresolved warnings, deliberate trade-offs). Hard failures are already
  fixed by then.
- [x] ~~How wide should the plain-language and "why" treatment go?~~ —
  **Resolved:** The whole pipeline (discovery → ship), with a "show technical
  detail" option on demand.
- [x] ~~What counts as "done" for the loop?~~ — **Resolved:** Every quality check
  green AND the agreed acceptance criteria met. (SR3)
- [x] ~~Does the build stage run fully autonomously?~~ — **Resolved:** It runs its
  loop autonomously but always stops before saving for human approval. Planning
  stages stay human-led. (SR1, SR2)
- [ ] Exact round-count limit and effort/cost budget for the loop — **Deferred
  (non-blocking):** "around three rounds / stop on no progress" is enough to build
  against; the precise number and any cost budget are a technical-refinement detail.
- [ ] Precise categories of "warning" the checkpoint surfaces vs. auto-resolves —
  **Deferred (non-blocking):** the principle (surface judgment calls, auto-fix hard
  failures) is settled; the exact taxonomy is a refinement detail.
- [ ] Whether "show technical detail" is a per-message reveal or a session-wide mode
  — **Deferred (non-blocking):** either satisfies SR6; pick during refinement.

---

## Shared Architecture Notes (Technical)

> Added by `/prd-refine`. The business content above is unchanged. This section
> is the canonical technical design shared by all three stories; each story spec
> elaborates its own slice consistently with it.

### What "implementation" means here

forge is a Claude Code plugin. Its behavior lives in **markdown instruction
files**, not application code:

- **Skill definitions** — `plugins/forge/skills/<skill>/SKILL.md` (frontmatter +
  numbered steps/phases that instruct Claude).
- **Skill-local references** — `plugins/forge/skills/<skill>/references/*.md`,
  loaded via `${CLAUDE_SKILL_DIR}/references/...`.
- **Plugin-shared references** — `plugins/forge/references/*.md`, loaded via
  `${CLAUDE_PLUGIN_ROOT}/references/...` (e.g. the existing `multi-choice.md`).
- **Scripts** — `${CLAUDE_SKILL_DIR}/scripts/*.sh` (e.g. `verify.sh`).

There is **no application runtime, HTTP API, or database** in scope. Every
sub-task is a markdown edit or a new markdown reference. Therefore, across all
three stories, **API Design, Data Model & Migrations, and UI/Frontend sections
are N/A and deleted.**

### New shared references introduced by this epic

| File                                       | Story | Purpose                                                                                                                                                                            |
| ------------------------------------------ | ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `plugins/forge/references/self-grill.md`   | 2     | The self-grill procedure: critique the stage's own draft, classify each gap as auto-resolvable vs. genuine decision, surface only genuine decisions + an "assumptions I made" summary. |
| `plugins/forge/references/plain-language.md` | 3   | The presentation/trust standard: plain-language default, a stated reason behind every recommendation, the "show technical detail" convention, and the explicit right-sizing note.  |

The existing `plugins/forge/references/multi-choice.md` is **extended** by Story 3
(reason-behind-the-recommendation + show-technical-detail hook); it is not
replaced.

### The unified gate set and loop contract (Story 1)

The loop's gate set reuses five existing forge gates **unchanged**:

| Gate              | Skill/agent              | Blocking signal              | Non-blocking signal           |
| ----------------- | ------------------------ | ---------------------------- | ----------------------------- |
| Build cleanliness | `verifier`               | FAIL                         | —                             |
| Requirements met  | spec acceptance criteria | any unmet criterion          | —                             |
| End-to-end        | `e2e`                    | FAIL (ERROR → stop, infra)   | NO_E2E (skip)                 |
| Security          | `security-review`        | FAIL                         | WARN → checkpoint             |
| Code quality      | `code-reviewer` agent    | `fail` finding               | `warn`-severity → checkpoint  |

- **Done** = `verifier` PASS ∧ all criteria met ∧ `e2e` PASS|NO_E2E ∧
  `security-review` PASS|WARN ∧ `code-reviewer` no-`fail`.
- **Bounded** = at most ~3 fix rounds; stop early when a round does not shrink
  the set of blocking failures ("no progress").
- **Never silent** = on cap reached / no-progress / `e2e` ERROR, the loop stops
  and surfaces exactly what is blocking; it saves nothing.
- The build↔ship handoff (where these gates run relative to commit) is decided
  in **[ADR-002](../../adr/002-build-loop-gate-ownership.md)**: the loop owns all
  five gates; `ship` gains a skip-gates mode for post-loop invocation.

### Cross-story dependencies & build order

- **Story 1 (build loop)** and **Story 2 (self-grill)** are independent and can
  be built in either order.
- **Story 3 (plain-language layer)** is a presentation standard the other two
  consume: Story 1's checkpoint summary and Story 2's surfaced decisions both
  render through it. Story 3 is independently valuable (it standardizes whatever
  stages exist today) but reaches full coverage once Stories 1 & 2 land — hence
  the recommended order **1 → 2 → 3** and the "soft" dependency in the Story Index.
- No story changes any external contract. `ship`'s standalone behavior, the
  individual gate skills, and `grill-me` all keep their current contracts.

### Testing & rollout implications (apply to every story)

- **Skills load at session start** (`blocker-skills-load-at-session-start`):
  edits to a SKILL.md or reference take effect only in a **fresh** session. All
  verification is therefore done by structured **manual dry-runs in a new
  session**, not by automated unit tests — there is no code to unit-test and no
  E2E framework in this repo. The `verifier` skill applies markdown/format
  linting only.
- Each story's **Test Scenarios** are concrete dry-run scripts (specific skill,
  specific scratch input, expected observable behavior), and its **Verification**
  section lists those dry-runs plus the `verifier` lint. **E2E Tests subsections
  are deleted** (no framework, no UI).
