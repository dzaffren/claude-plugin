# Calibrated, Framework-Grounded Pushback

**Ticket:** TBD

**Epic Overview:** [spec.md](spec.md)

**Discovery Brief:** docs/discovery/build-once-quality/brief.md

forge's thinking stages — discovery, requirements (PRD), and refinement — challenge
weak product decisions instead of quietly accepting them. Every challenge is rooted
in one of four trusted product-thinking lenses, is phrased in plain language, and can
be accepted or overruled in a single step. The person running forge experiences it as
a sharp thinking partner that catches the decision they'd have regretted — without
nagging, and without ever raising the same point twice.

## User Story

As an indie builder shaping a product with forge, I want forge to push back on my shaky
product decisions in a grounded, one-and-done way, so that I catch the wrong calls
before I build them — without being interrogated or slowed down.

## Background & Context

**Current state:**

- forge's discovery, requirements, and refinement stages ask questions and produce
  artifacts, but the way they challenge decisions is uneven. Discovery does a light
  inline check, the requirements stage runs a heavier interrogation, and refinement
  has its own style.
- None of these stages reason from a consistent, recognised set of product-thinking
  lenses, and none of them adjust how hard they push based on how risky a decision is.

**Problem:**

- When forge accepts a shaky decision and carries it forward, the builder ends up
  building the wrong thing and rebuilding it later. When forge questions everything
  indiscriminately, the builder feels interrogated and loses momentum.
- Because the challenges aren't anchored to anything recognisable, even the good ones
  can feel arbitrary rather than trustworthy — so the builder dismisses them.

## Target User & Persona

- **Who:** An indie builder, founder, or product-minded developer running forge to
  shape and build their own product. They are decisive and time-pressured, and they
  value a partner that sharpens their thinking rather than one that rubber-stamps it.
- **Context:** Mid-session, working through discovery, requirements, or refinement,
  describing goals and decisions in their own words and expecting to keep moving.
- **Current workaround:** They rely on their own judgement, or they reach for a
  separate, heavier stress-test, and they often only discover a weak decision after
  they've already built on top of it.

## Goals

- Make forge challenge weak product decisions in discovery, requirements, and
  refinement using four trusted thinking lenses — firmly, but never more than once on
  the same point.
- Phrase every challenge in plain language that names the concern, never the lens.
- Let the builder accept or overrule any challenge in a single step, with an optional
  one-line reason, and keep moving.
- Calibrate the pushback so it fires on genuinely shaky, high-risk decisions and stays
  quiet on decisions that are well-evidenced and obviously sound.

## Non-Goals

- The concise inline digest of each finished artifact is a separate story
  (see [spec-inline-summaries.md](spec-inline-summaries.md)) and is not covered here.
- A user-set "challenge intensity" dial. Calibration here is achieved through the
  one-step override and the never-twice rule, not a configurable setting.
- Changing how the build stage writes code, or adding code-quality / over-engineering
  guardrails to refinement and build. Those are deferred to a later cycle.

## The Four Thinking Lenses

Every challenge forge raises must trace to at least one of these four lenses. forge
reasons with the lens internally but never says its name to the builder.

| Lens                    | The question it asks                                                  | How the builder hears it (example plain phrasing)                                                  |
| ----------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| The real user job       | Is the actual job the user is trying to get done understood?          | "What is the user actually trying to get done when they reach for this?"                           |
| Outcome vs. output      | Is this a measurable change for the user, or just a thing we shipped? | "This looks like an output, not an outcome — what changes for the user?"                           |
| The riskiest assumption | What has to be true for this to work, and how will we test it?        | "This relies on users wanting X. What's the cheapest way to check that's true before we build it?" |
| Priority / impact       | Is this the right thing to build first?                               | "Is this the highest-impact thing to build now, or is something else more urgent?"                 |

## User Workflow

1. **The builder makes a product decision** — they describe a goal, a problem, a
   feature, or a priority in their own words during discovery, requirements, or
   refinement.
2. **forge weighs it against the four lenses** — silently. If the decision is shaky or
   high-risk against at least one lens, forge raises a single plain-language challenge
   naming the concern.
3. **The builder resolves it in one step** — they either accept the challenge (and
   reshape the decision) or overrule it (keep their decision, optionally adding a
   one-line reason). Either way, they move on immediately.
4. **forge records the decision and moves on** — it does not raise that same point
   again for the rest of the run. The builder reaches the end with a set of deliberate,
   grounded decisions and no sense of having been nagged.

## Acceptance Criteria

> Scenarios are written from the perspective of the person running forge.

### Scenario: forge challenges an output mistaken for an outcome

```gherkin
Given I am in a discovery session with forge
When I say my goal is "ship a CSV export button this month"
Then forge challenges that this looks like an output, not a measurable outcome
  And forge asks what would change for the user if it shipped
  And forge does not use any framework name in the challenge
```

### Scenario: forge challenges a solution masquerading as a problem

```gherkin
Given I am in a discovery session with forge
When I describe the user problem as "users need a better dashboard"
Then forge points out that "a better dashboard" is a solution, not a user problem
  And forge asks what the user is actually trying to get done
  And the challenge is phrased in plain language
```

### Scenario: forge challenges an untested riskiest assumption

```gherkin
Given Priya is refining a spec for an in-app notifications feature
When she states the plan assumes "users will turn notifications on and keep them on"
Then forge flags that this is the assumption the whole feature rests on
  And forge asks for the cheapest way to test that before building it
  And forge offers to capture the test as the next action
```

### Scenario: forge challenges building a low-priority item first

```gherkin
Given I am in the requirements stage with three features in mind
  And I have framed them as:
    | feature                  | evidence                          |
    | custom report builder    | one enterprise prospect asked     |
    | fix slow login           | most users hit it daily           |
    | dark mode                | a handful of users requested it   |
When I say I want to build the custom report builder first
Then forge questions whether that is the highest-impact thing to build now
  And forge notes that "fix slow login" affects most users daily
  And forge asks me to confirm the order on purpose or reconsider
```

### Scenario: builder accepts a challenge in one step and reshapes the decision

```gherkin
Given forge has challenged my goal "ship a CSV export button" as an output, not an outcome
When I accept the challenge
Then forge helps me restate the goal as a measurable outcome
  And we continue immediately from the reshaped goal
  And forge does not raise the output-versus-outcome point on this goal again
```

### Scenario: builder overrules a challenge in one step with a reason

```gherkin
Given forge has challenged my plan to build the custom report builder first
When I overrule the challenge with the reason "this prospect closes a deal that funds the quarter"
Then forge records my decision and my reason
  And we continue with the custom report builder as the first priority
  And forge does not re-raise the priority of the custom report builder again in this run
```

### Scenario: builder overrules a challenge without giving a reason

```gherkin
Given forge has challenged a decision of mine
When I overrule it without adding a reason
Then forge accepts the override and moves on
  And forge does not require me to justify the decision
  And we keep moving without interruption
```

### Scenario: forge never blocks twice on the same point within a run

```gherkin
Given forge challenged my notifications assumption during discovery
  And I overruled it with a one-line reason
When the same notifications assumption comes up again during refinement in the same run
Then forge does not re-challenge that assumption
  And forge treats it as a decision I have already made
  And forge proceeds on the basis of my recorded decision
```

### Scenario: forge stays quiet on a well-evidenced, obviously sound decision

```gherkin
Given I am in discovery and my goal is "reduce checkout abandonment, currently 40 percent"
  And I support it with analytics showing where users drop off
When I select "simplify the checkout form" as the problem to tackle first
Then forge does not raise a challenge on this decision
  And forge lets me continue without friction
  And forge reserves its pushback for the decisions that actually need it
```

### Scenario: a challenge that cannot be tied to a lens is not raised

```gherkin
Given I have made a sound, evidence-backed product decision
When forge has no concern rooted in the user's job, outcomes, the riskiest assumption, or priority
Then forge does not invent an objection
  And forge does not raise a challenge for the sake of it
  And I am not slowed down by arbitrary questioning
```

### Scenario Outline: each shaky decision draws a challenge rooted in the matching lens

```gherkin
Given I am in a forge thinking stage
When I state "<decision>"
Then forge raises a plain-language challenge about "<concern>"
  And the challenge is resolvable in a single accept-or-overrule step

Examples:
  | decision                                            | concern                                              |
  | the goal is to "add a settings page"                | whether this is an outcome or just an output         |
  | the user problem is "we need an AI assistant"       | whether this is the real user job or a solution      |
  | the plan assumes users will pay for the premium tier| the assumption the plan rests on and how to test it  |
  | build the rarely-used admin panel before login fixes| whether this is the right thing to build first       |
```

### Scenario: the builder can always keep moving after a challenge

```gherkin
Given forge has raised a challenge on one of my decisions
When I choose either to accept or to overrule it
Then I am never stuck on the challenge
  And forge always offers a one-step way to resolve it and continue
  And the session keeps progressing toward a finished artifact
```

## Business Rules & Constraints

- **Every challenge maps to a lens.** forge may only challenge a product decision when
  the concern traces to at least one of the four lenses: the real user job, outcome
  vs. output, the riskiest assumption, or priority/impact. A concern that maps to no
  lens is not raised.
- **Plain language only.** A challenge names the concern in everyday words (for
  example, "this looks like an output, not an outcome"). forge never says the lens
  name to the builder. If the builder asks what lens forge is using, forge may then
  name it.
- **One-step override, always.** Every challenge can be accepted or overruled in a
  single action. A one-line reason is optional; forge never demands a justification.
- **Never block twice on the same point.** Once the builder accepts or overrules a
  challenge, forge records the decision and does not re-raise that same point for the
  rest of the run — including across discovery, requirements, and refinement in that
  run.
- **Calibrated, not constant.** forge pushes back on shaky or high-risk decisions — a
  solution disguised as a problem, an output mistaken for an outcome, an untested risky
  assumption, or a low-priority item being built first — and stays silent on decisions
  that are well-evidenced and obviously sound.
- **No technical concerns.** Challenges are about users, problems, outcomes,
  assumptions, and priorities — never about code, architecture, or implementation.

## Success Metrics

- In a real end-to-end run on a genuine feature, forge catches at least one weak
  decision the builder would otherwise have carried forward — confirmed by the builder
  rating the pushback as "calibrated".
- The builder is never asked to resolve the same challenge twice in a single run —
  zero repeated challenges on an already-resolved point.
- Every challenge forge raised maps to one of the four lenses — zero challenges the
  builder judges "arbitrary".
- The resulting spec goes to build without a requirement-level rewrite — zero rework
  caused by a weak decision that forge let slide.

## Dependencies

- A real, genuine feature idea to run the end-to-end experiment from the discovery
  brief — calibration is validated by dogfooding one real feature through discovery,
  requirements, and refinement, not by a synthetic example.

## Open Questions

- [x] ~~Which thinking lenses ground the pushback?~~ — **Resolved:** the real user job,
      outcome vs. output, the riskiest assumption, and priority/impact.
- [x] ~~How is pushback kept from frustrating the builder?~~ — **Resolved:** a one-step
      override that is always available, plus the never-block-twice rule.
- [x] ~~Does forge name the lenses to the builder?~~ — **Resolved:** no. Challenges are
      phrased in plain language; the lens is named only if the builder explicitly asks.
- [x] ~~How is "calibrated" judged?~~ — **Resolved:** the builder confirms the pushback
      caught at least one weak decision and never asked the same question twice, during
      the real end-to-end run.

---

## Functional Requirements

- **Single source of truth.** The four lenses, the calibration rule, the
  one-step-override rule, and the never-block-twice rule live in one new shared
  reference, `plugins/forge/references/pushback-frameworks.md`. Skills reference
  it via the existing `${CLAUDE_PLUGIN_ROOT}/references/` token; they do not
  restate the rules inline.
- **Lens traceability.** Before forge surfaces any challenge, it must map the
  concern to ≥1 of the four lenses. If no lens matches, no challenge is raised
  (idempotent on sound decisions — re-running the same input yields no new
  objection).
- **Plain-language framing.** The user-facing challenge names the concern in
  everyday words and never emits the strings "Jobs-to-be-Done", "JTBD", "North
  Star", "riskiest assumption", or "RICE". Lens names appear only if the user
  explicitly asks "what framework are you using?".
- **One-step resolution.** Each challenge is presented with an accept/overrule
  affordance resolvable in a single turn. An overrule reason is optional; forge
  never re-prompts for justification.
- **Decision ledger (run-scoped).** forge maintains an in-conversation record of
  resolved points (accepted or overruled) for the current run and consults it
  before raising a challenge, so the same point is never re-raised — including
  across discovery → prd → prd-refine within one continuous session.
- **Calibration gate.** A challenge fires only when the decision is shaky/
  high-risk against a lens (solution-as-problem, output-as-outcome, untested
  risky assumption, low-priority-first). Well-evidenced, obviously-sound
  decisions pass without a challenge.

## Permissions & Security

N/A — no authorization surface. Behavioural prompt changes only; no data is
read, written, or transmitted beyond the conversation.

## System Design

This story implements the **`pushback-frameworks.md` producer** plus the edits
to its four consumers. See the epic overview's _Shared System Design_ for the
component diagram and tradeoffs. Story-specific contract:

`plugins/forge/references/pushback-frameworks.md` must define, at minimum:

1. **The four lenses** — for each: the internal question, 2–3 plain-language
   phrasings the user hears, and the "shaky vs. sound" signal that triggers it.
2. **Calibration rule** — "challenge shaky/high-risk decisions; stay silent on
   well-evidenced, obviously-sound ones; never invent an objection."
3. **One-step-override rule** — every challenge accept/overrule in one turn,
   reason optional.
4. **Never-block-twice rule** — record each resolution; do not re-raise within
   the run, including across skills.
5. **Plain-language rule** — name the concern, never the lens; reveal the lens
   only on explicit user request.

## Threat Model Checklist

- **Data classification:** N/A — no PII/secrets; prompt instructions only.
- **Attack surface:** N/A — no endpoints, parsers, uploads, or network calls.
- **Authn / authz changes:** N/A — none.
- **Dependency additions:** None.

## Architecture Notes

- **New file:** `plugins/forge/references/pushback-frameworks.md` (exemplar to
  mirror for tone/structure: `plugins/forge/references/multi-choice.md`).
- **Edited files:**
  - `plugins/forge/skills/grill-me/SKILL.md` — in _Step 2 — Walk each branch_
    ("What makes a good question"), require every question/challenge to trace to
    a lens and to follow the calibration + override + never-twice rules; add a
    pointer to `pushback-frameworks.md`. This is the shared engine, so the `/prd`
    Step 4 gate and `/prd-refine` Step 1.5 gate inherit the behaviour.
  - `plugins/forge/skills/product-discovery/SKILL.md` — _Step 4: Quick
    pressure-test_ and _Step 6: Ideas and the leap of faith_: ground the inline
    checks and the solution-vs-problem reframe in the lenses; honour override +
    never-twice. (Discovery deliberately does not call `grill-me`, so it must
    reference `pushback-frameworks.md` directly.)
  - `plugins/forge/skills/prd/SKILL.md` — _Step 4: Product Interrogation Gate_:
    add a pointer to `pushback-frameworks.md` so the grill stays lens-grounded
    and product-scoped.
  - `plugins/forge/skills/prd-refine/SKILL.md` — _Step 1.5: Design Interrogation
    Gate_: same pointer for the standalone path (when no PRD was pre-loaded).
- **Verification constraint:** skills load at session start (repo learning
  `blocker-skills-load-at-session-start`) — exercise these edits in a fresh
  session, never the one that wrote them.

## Implementation Plan

| #   | Sub-task                                                                                                    | Label                  | Size | Files                                                                                                                                                      |
| --- | ----------------------------------------------------------------------------------------------------------- | ---------------------- | ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Author `pushback-frameworks.md` (four lenses + calibration + override + never-twice + plain-language rules) | INDEPENDENT            | M    | `plugins/forge/references/pushback-frameworks.md` (new)                                                                                                    |
| 2   | Wire the four lenses + rules into the shared interrogation engine                                           | SEQUENTIAL (after 1)   | S    | `plugins/forge/skills/grill-me/SKILL.md`                                                                                                                   |
| 3   | Ground discovery's inline checks + leap-of-faith in the lenses                                              | SEQUENTIAL (after 1)   | S    | `plugins/forge/skills/product-discovery/SKILL.md`                                                                                                          |
| 4   | Add lens pointer to the prd interrogation gate                                                              | SEQUENTIAL (after 1)   | S    | `plugins/forge/skills/prd/SKILL.md`                                                                                                                        |
| 5   | Add lens pointer to the prd-refine interrogation gate                                                       | SEQUENTIAL (after 1)   | S    | `plugins/forge/skills/prd-refine/SKILL.md`                                                                                                                 |
| 6   | Add eval cases asserting lens-grounded, calibrated, never-twice pushback                                    | SEQUENTIAL (after 2–5) | S    | `plugins/forge/skills/product-discovery/evals/evals.json`, `plugins/forge/skills/prd/evals/evals.json`, `plugins/forge/skills/prd-refine/evals/evals.json` |

Sub-tasks 2–5 are independent of each other (each edits a different file) but all
depend on sub-task 1 producing the reference doc.

## Negative Constraints

- Do NOT change the existing business content of any spec, or the discovery
  brief template / brief outputs.
- Do NOT alter the forbidden-phrases list or the Opportunity-Solution-Tree
  framing already in `product-discovery` — only add lens grounding.
- Do NOT introduce a user-set "challenge intensity" setting (explicit non-goal).
- Do NOT make `grill-me` ask product owners about technical/architecture
  concerns — preserve its existing audience-matching rule.
- Do NOT touch `build`, `ship`, or any non-thinking skill.

## Test Scenarios

> Implementation-level checks. Forge skills are validated by `evals.json` cases
> and a manual fresh-session run; there are no unit/HTTP tests in this repo.

- **TS1 — Lens trace, output-as-outcome:** Input goal "ship a CSV export button
  this month" in a discovery run → challenge text contains an output-vs-outcome
  concern in plain language; asserts the string "North Star" / "outcome metric"
  jargon is absent. Eval expectation added to `product-discovery/evals/evals.json`.
- **TS2 — Calibration silence:** Input goal "reduce checkout abandonment from
  40%" with supporting analytics + problem "simplify the checkout form" → no
  challenge raised on that selection. Eval expectation: "does not manufacture an
  objection on a well-evidenced decision".
- **TS3 — Never-twice across skills:** In one session, overrule the notifications
  assumption in discovery, then reach `prd-refine` Step 1.5 → the same assumption
  is not re-challenged. Eval expectation added to `prd-refine/evals/evals.json`.
- **TS4 — One-step overrule, no reason:** Challenge raised → user replies
  "overrule" with no reason → forge proceeds without demanding justification.
  Eval expectation: "accepts a bare override".
- **TS5 — Priority lens:** Three features (custom report builder / fix slow login
  / dark mode) with the slow-login evidence strongest → choosing the report
  builder first draws a priority challenge that cites the slow-login impact. Eval
  expectation added to `prd/evals/evals.json`.

## Verification

- **Backend tests:** N/A — no application code.
- **Eval suite:** Run forge's eval harness against the three updated
  `evals.json` files; the new cases (TS1–TS5) must pass.
- **Browser / UI:** N/A — no UI.
- **E2E:** N/A — no E2E framework in this repo (`package.json` absent); the E2E
  mapping section is intentionally omitted.
- **Manual fresh-session run (the brief's experiment):** In a new session, take
  one real feature through discovery → prd → prd-refine and confirm: ≥1 weak
  decision was challenged, no point was raised twice, every challenge was
  plain-language and lens-traceable, and a sound decision passed without
  friction.
