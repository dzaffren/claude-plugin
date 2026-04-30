# Learn Skill Eval — Contradiction Detected

## Result: CONFLICT DETECTED — NO WRITES PERFORMED

## What I did

1. Loaded the `/learn` skill at `plugins/did-workflow/skills/learn/SKILL.md` and its `references/types.md`.
2. Interpreted the user prompt — "From now on we use Jest, not Vitest. New service is Jest-only." — as a **capture** request for a new convention (absolute-language signal: "from now on").
3. Ran the mandatory **Step 2 dedupe check** by reading `.claude/learnings/INDEX.md`.
4. Found an existing entry that overlaps on topic: `convention-use-vitest.md`.
5. Read the existing learning file and confirmed the semantics.
6. Read `CLAUDE.md` and confirmed the Vitest rule is also mirrored in its `## Learnings` section.

## Why this is a contradiction, not a near-duplicate

The existing learning (`convention-use-vitest`) states:

> "Use Vitest for new and existing tests. Do not add new Jest tests. ... The only place a new Jest test is acceptable is inside `packages/legacy-billing/`, and even there the preference is to port it when feasible."

The new observation states:

> "From now on we use Jest, not Vitest. New service is Jest-only."

These directly invert each other on the primary rule:

- Existing: **Vitest is the default; Jest is a narrow legacy exception.**
- New: **Jest is the default going forward (at least for the new service); Vitest is being deprioritised or scoped out.**

This is not a wording refinement (which would be handled as `update` mode). It is a direct reversal of the default test runner, so per Step 2:

> **Contradiction** (new rule conflicts with existing) — stop and ask the user. Don't silently overwrite; a contradiction is a signal that either the old rule is stale or the new one is wrong, and only the user can resolve that.

I therefore **stopped before Step 3** and made **no writes**.

## Files modified

**NONE.** Specifically:

- Did NOT create any new file under `.claude/learnings/`.
- Did NOT edit `.claude/learnings/convention-use-vitest.md`.
- Did NOT edit `.claude/learnings/INDEX.md`.
- Did NOT edit `CLAUDE.md`.

## Question surfaced to the user

> I can't capture this cleanly — it contradicts an existing learning in this repo.
>
> - **Existing** (`.claude/learnings/convention-use-vitest.md`, captured 2026-02-10): "Use Vitest for new and existing tests. Do not add new Jest tests. The only acceptable Jest usage is inside `packages/legacy-billing/`." This rule is also listed in `CLAUDE.md` under `## Learnings`.
> - **New** (just now): "From now on we use Jest, not Vitest. New service is Jest-only."
>
> These directly contradict on the default test runner. Before I write anything, I need you to tell me which is right. A few possibilities:
>
> 1. **Full reversal** — the team has flipped back to Jest across the repo. I should `/learn remove use-vitest` (dropping it from the index and from `CLAUDE.md`) and then capture a new `convention-use-jest` learning covering the whole repo.
> 2. **Scoped exception** — Vitest is still the default, but "the new service" is a specific package/directory that should use Jest (similar to how `packages/legacy-billing/` is already exempt). In that case I'd keep the Vitest learning and either (a) expand its `**How to apply:**` to name the new service as a second exception, or (b) capture a new scoped `pattern-new-service-uses-jest` learning pointing at the specific path.
> 3. **The old rule is stale** — Vitest is no longer endorsed at all, and the old learning should be removed without replacement.
>
> Which is it? And if it's option 2, what's the path/name of the new service so I can scope the rule correctly?

## Skill-procedure compliance

- Step 1 (understand observation): done — type=convention, rule extracted, absolute language noted.
- Step 2 (dedupe check): done — contradiction found, halted per skill instruction.
- Steps 3–6: **intentionally skipped** because Step 2 mandates stopping on contradiction.

The skill behaved correctly: the contradiction trap was detected and no silent overwrite occurred.
