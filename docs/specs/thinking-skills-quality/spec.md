# Framework-Grounded Thinking & Inline Summaries — Overview

**Discovery Brief:** docs/discovery/build-once-quality/brief.md

## Summary

This epic raises the quality of forge's "thinking" stages — discovery, PRD,
and refinement — so they help users build the right product right the first
time. It does two things: gives forge a calibrated, framework-grounded spine
that challenges weak product decisions without nagging, and surfaces a digest
of every artifact inline so users can decide without opening files. The
audience is the person running forge to shape and build a product (an indie
builder, founder, or product-minded developer).

## Background & Context

**Current state:**

- forge's discovery, PRD, and refinement stages ask questions and produce
  artifacts (a discovery brief, PRD specs, refined specs).
- Pushback is uneven: discovery has a light inline check, the PRD stage runs a
  heavier interrogation, and refinement has its own. None of them reason from
  named, recognised product frameworks, and none calibrate how hard they push.
- When a stage finishes, the user is told a file was written and generally has
  to open it to see what was actually decided.

**Problem:**

- forge can behave like a "yes-man" — accepting a shaky decision and carrying
  it forward — which is how a product ends up needing to be rebuilt. At the
  other extreme, undirected questioning frustrates the user.
- Because reasoning isn't anchored to known frameworks, the challenges forge
  does raise can feel arbitrary rather than trustworthy.
- Forcing the user to open files to review output adds friction at every step
  and slows the decision loop — the opposite of "decide quickly and keep moving".
- forge is pre-launch. These gaps are the owner's main blockers to sharing it
  publicly: output that isn't consistently good enough to stake a name on.

## Goals

- Make forge challenge weak product thinking using recognised frameworks
  (Jobs-to-be-Done, outcome/North-Star, riskiest-assumption, and
  prioritisation) — firmly, but never more than once on the same point.
- Let the user accept or overrule any challenge in a single step and keep moving.
- Show a concise digest of every artifact inline, with a clear option to open
  the full file when the user wants the detail.
- Together, produce specs the user would confidently hand to a build without
  rework.

## Non-Goals

- Changing how the build stage writes code, or adding "no over-engineering" /
  UI-UX-quality guardrails to refinement and build. That was considered and
  deferred to a later cycle (see the brief's deferred branches).
- Improving robustness/polish of other stages, or making the statusline more
  discoverable — both deferred in discovery.
- Adding a configurable "challenge intensity" setting. The calibration approach
  here is the one-step override, not a user-set intensity dial.

## Story Index

| Ticket | Story                                   | Spec                                                       | Type        | Status      | Dependencies |
| ------ | --------------------------------------- | ---------------------------------------------------------- | ----------- | ----------- | ------------ |
| TBD    | Calibrated, framework-grounded pushback | [spec-calibrated-pushback.md](spec-calibrated-pushback.md) | User-facing | Not Started | —            |
| TBD    | Inline artifact digests                 | [spec-inline-summaries.md](spec-inline-summaries.md)       | User-facing | Not Started | —            |

## Shared Business Rules

- **Four grounding frameworks.** Whenever forge challenges a product decision in
  discovery, PRD, or refinement, the challenge must be traceable to at least one
  of: Jobs-to-be-Done (is the real user job understood?), outcome / North-Star
  (does this map to a measurable outcome, not just output?), riskiest assumption
  (what must be true, and how will we test it?), or prioritisation / impact (is
  this the right thing to build now?).
- **Never block twice on the same point.** forge may raise a challenge once. If
  the user accepts or overrules it, forge records the decision and moves on — it
  does not re-litigate the same point later in the same run.
- **One-step override always available.** Every challenge must be dismissable or
  acceptable by the user in a single action, with a one-line reason optional.
- **Digest-then-detail.** Every artifact forge writes is presented as a concise
  inline digest of its key decisions and sections, followed by a one-line offer
  to open the full file. The full file is never withheld — the digest is an
  addition, not a replacement.
- **Honest framing.** A challenge states which concern it's raising in plain
  language (e.g. "this looks like an output, not an outcome") — it does not
  invoke framework jargon at the user.

## User Journey Map

> How the two stories connect across a single pass through forge.

1. **User brings an idea** — they start a discovery session with a fuzzy idea.
   forge challenges the shaky parts (Is this the real job? Is the goal an
   outcome or just an output?), the user accepts or overrules each in one step,
   and at the end sees a digest of the brief inline. _(Stories: pushback,
   digests)_
2. **User shapes requirements** — they move to the PRD stage. forge pressure-
   tests scope and priority against the frameworks, the user resolves each
   challenge once, and the PRD is presented as an inline digest with an offer to
   open it. _(Stories: pushback, digests)_
3. **User refines the spec** — refinement challenges any remaining risky
   assumptions before build, and the refined spec is again shown as a digest.
   _(Stories: pushback, digests)_
4. **Completion** — the user has made a series of deliberate, framework-grounded
   decisions and has reviewed every artifact without opening a single file,
   ending with a spec they'd hand to a build without rework.

## Success Metrics

- In a real end-to-end run (discovery → PRD → refinement on one genuine
  feature), the user can review every artifact and reach the build step without
  opening a file — measured by the user confirming "I didn't need to open
  anything".
- The user rates the pushback as "calibrated" — it caught at least one weak
  decision they'd otherwise have carried forward, and never made them answer the
  same challenge twice.
- The resulting spec goes to build without requiring a rewrite of the
  requirements (zero requirement-level reworks on the test feature).
- Every challenge forge raised maps to one of the four named frameworks (no
  "arbitrary" challenges).

## Dependencies

- A real, genuine feature idea to run the end-to-end experiment from the
  discovery brief — the validation depends on dogfooding, not a synthetic example.

## Rollout Strategy

- Deliver the pushback story first (it's the core value and the riskiest
  assumption — calibration), then the digests story.
- Validate via the discovery brief's experiment: run one real feature through
  the full chain and judge calibration, file-free review, and build-once quality.

## Open Questions

- [x] ~~Which frameworks ground the pushback?~~ — **Resolved:** Jobs-to-be-Done,
      outcome/North-Star, riskiest-assumption, and prioritisation/impact.
- [x] ~~How is pushback kept from frustrating users?~~ — **Resolved:** one-step
      override; never block twice on the same point.
- [x] ~~How much does an inline digest show?~~ — **Resolved:** concise digest of
      key decisions/sections plus a one-line offer to open the full file.
- [x] ~~Does this cycle touch refinement/build code-quality guardrails?~~ —
      **Resolved:** no — deferred to a later cycle. This epic covers the thinking
      stages and inline digests only.

---

## Shared System Design (technical)

> This epic ships **no application code**. The "implementation" is edits to the
> forge plugin's skill instructions (Markdown) plus two new shared reference
> documents. There is no backend, frontend, database, HTTP API, or E2E
> framework in this repo (no `package.json`). "Interfaces" below means the
> Markdown contracts that skills read and follow at runtime.

### Components

- **Two new shared reference docs** under `plugins/forge/references/` — the
  single source of truth each thinking skill points at, mirroring the existing
  `plugins/forge/references/multi-choice.md` pattern:
  - `plugins/forge/references/pushback-frameworks.md` — the four lenses, the
    calibration rule, the one-step-override rule, and the never-block-twice rule.
    Consumed by Story 1 (Calibrated pushback).
  - `plugins/forge/references/artifact-digest.md` — the digest-then-detail
    presentation contract (what a digest contains, the one-line open offer, the
    multi-file set rule). Consumed by Story 2 (Inline digests).
- **`grill-me` skill** (`plugins/forge/skills/grill-me/SKILL.md`) — the shared
  interrogation engine that `/prd` (Step 4) and `/prd-refine` (Step 1.5) invoke.
  Story 1 grounds its questioning in the four lenses and adds the calibration /
  override / never-twice rules here so every caller inherits them.
- **The three thinking skills** — `product-discovery`, `prd`, `prd-refine` — each
  edited to (a) reference `pushback-frameworks.md` where it challenges decisions
  (Story 1) and (b) reference `artifact-digest.md` at its hand-off/closing step
  (Story 2).

### Interfaces (Markdown contracts)

| Contract                                                 | Producer            | Consumers                                             |
| -------------------------------------------------------- | ------------------- | ----------------------------------------------------- |
| `plugins/forge/references/pushback-frameworks.md`        | Story 1             | `grill-me`, `product-discovery`, `prd`, `prd-refine`  |
| `plugins/forge/references/artifact-digest.md`            | Story 2             | `product-discovery`, `prd`, `prd-refine`              |
| Reference path token `${CLAUDE_PLUGIN_ROOT}/references/` | existing convention | all skills (same token already used for multi-choice) |

### Data flow

```mermaid
flowchart TD
    PF["pushback-frameworks.md (new)"] --> GM["grill-me SKILL"]
    PF --> PD["product-discovery SKILL"]
    PF --> PR["prd SKILL"]
    PF --> PRF["prd-refine SKILL"]
    AD["artifact-digest.md (new)"] --> PD
    AD --> PR
    AD --> PRF
    GM --> PR
    GM --> PRF
    PD -->|writes brief + digest| U["User decides inline"]
    PR -->|writes spec(s) + digest| U
    PRF -->|writes refined spec + digest| U
```

### Tradeoffs considered

- **Shared reference docs vs. inlining rules into each skill.** Chosen: shared
  docs. Mirrors the established `multi-choice.md` pattern, keeps the four lenses
  and the digest contract in one place, and avoids four copies drifting apart.
  Rejected inlining — it would duplicate the rules across `grill-me` plus three
  skills and make calibration tuning a four-file edit. No ADR written: this
  follows an existing repo convention rather than introducing a new pattern.
- **Extend `grill-me` vs. a new pushback skill.** Chosen: extend `grill-me`,
  because `/prd` and `/prd-refine` already route their interrogation through it —
  one edit propagates to both. A separate skill would orphan those call sites.

### Cross-cutting verification constraint

Per the repo learning **`blocker-skills-load-at-session-start`**, skills load at
session start and do **not** hot-reload mid-session. Every change in this epic is
a skill/reference edit, so it cannot be exercised in the same session that writes
it. Verification (the discovery brief's end-to-end experiment) must run in a
**fresh session** after the edits land. This applies to both stories and is the
single most important gotcha for `/build` and for the human validating the work.

### Threat Model Checklist (epic-level)

- **Data classification:** N/A — no PII, secrets, or data storage. Changes are
  prompt/Markdown instructions only.
- **Attack surface:** N/A — no new endpoints, deserializers, uploads, or
  network surface. The only new artifacts are Markdown docs read by the model.
- **Authn / authz changes:** N/A — none.
- **Dependency additions:** None. No new packages.
- **Note:** digests (Story 2) echo artifact content the user authored back into
  the conversation; no external transmission, so no data-exposure risk beyond
  what the user already wrote.
