---
name: discover
description: >
  Product discovery before any requirements are written. Use when the user has
  a vague idea, wants to figure out what to build, or says "let's discover",
  "I have an idea", "what should we build", "brainstorm this". Produces a
  discovery brief (Markdown + HTML visualization) that feeds /spec.
---

# Discover

Turn a fuzzy idea into a validated opportunity before anything is specified or
built. This is a conversation, not a form. One question at a time, plain
language, no technical talk — discovery is about users and outcomes.

## Steps

1. **Find the starting point.** Vague idea, specific problem, or clear
   outcome? Ask just enough to tell which.

2. **Frame the outcome.** Push for something measurable, time-bound, and
   worth caring about ("increase trial-to-paid from 12% to 20% by Q3", not
   "improve onboarding"). If the user already has one, confirm and move on.

3. **List opportunities.** 3–5 unmet needs or pain points — not solutions.
   "Can't find their data" is an opportunity; "needs a dashboard" is a
   solution in disguise. For each, note evidence strength: strong (real user
   data), moderate (indirect signals), weak (gut feel). Weak is fine — say so.

4. **Pick one.** Weigh size, evidence, and how directly it moves the outcome.
   State the pick and why. The rest stay on the tree for later.

5. **Sketch 2–4 solutions** for the picked opportunity. For each: what the
   user would experience, the riskiest assumption, and confidence in it. For
   the leading one, suggest a days-not-weeks experiment to test the assumption
   (prototype test, concierge, data analysis, 5–8 user interviews).

6. **Draw the tree.** Mermaid `flowchart TD`: outcome at top, opportunities
   below, solutions under the picked opportunity, experiment at the leaf.
   Grey out deferred branches
   (`style X fill:#f5f5f5,stroke:#bdbdbd,color:#9e9e9e`).

7. **Write the brief** to `docs/discovery/{kebab-name}.md`: outcome,
   opportunities with evidence, the pick and rationale, solution candidates,
   experiment, the tree diagram, open questions. Shortest complete version.

8. **Render and hand off.** Generate the HTML view (spec-html skill), then
   tell the user: the brief path, that `/spec` will pick it up automatically,
   and end with the `file://` link on its own line.

## Resuming (`/discover continue {name}`)

Discovery spans sessions — users get interviewed, analytics get checked.
When resuming (explicitly, or when a brief for this topic already exists in
`docs/discovery/`):

1. Read the existing brief. Summarize in a few lines: what's decided, what
   questions are open, which step it stopped at.
2. Ask which open questions now have answers. Fill them in.
3. Continue from the first unresolved step. Never re-litigate settled
   decisions — they're in the brief for a reason.

When a session ends with questions still open, write the brief anyway with
an **Open questions** section (what's unknown, who can answer, what it
blocks) and say resuming is `/discover continue {name}`.

## Ground rules

- If the user says "I already know the problem, let's go" — fast-track:
  capture the outcome and riskiest assumption, note what was skipped.
- If a question can't be answered now, log it as an open question with who to
  ask, and keep going. Don't stall the session on it.
- Stay strategic. No user stories, acceptance criteria, or scope lists here —
  that is /spec's job.
