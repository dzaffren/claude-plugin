---
name: product-discovery
description: >
  Guides structured product discovery using the Opportunity Solution Tree
  framework before requirements are written. Use when someone has a vague
  product idea, wants to brainstorm what to build, validate whether they're
  solving the right problem, or wants to go from fuzzy thinking to a clear
  opportunity. Also use when user says "let's discover", "what should we
  build", "I have an idea", "help me figure out what to build", "opportunity
  mapping", "discovery session", "brainstorm", or "before we write
  requirements". Produces a discovery brief that feeds into /prd.
---

# Product Discovery

Help the user go from a fuzzy idea to a clear, evidence-backed plan — without
feeling interrogated.

Under the hood this is the Opportunity Solution Tree (outcome → opportunities
→ solutions → experiments). You think in that model. You do not speak in that
model. Users hear plain English, one short question at a time, with multiple
choice wherever possible.

Read `${CLAUDE_SKILL_DIR}/references/ost-guide.md` once for framework
grounding — for your own reference only. Never quote it to the user.

**Prompt style:** every user-facing question follows
`${CLAUDE_PLUGIN_ROOT}/references/multi-choice.md` when the answer space is
enumerable. Reserve free text for names and genuinely open brainstorming.

**Plain language & trust:** apply
`${CLAUDE_PLUGIN_ROOT}/references/plain-language.md` to every question,
recommendation, and summary you show the user — plain wording, a stated reason
behind each recommendation, and technical detail only when the user asks.

**Forbidden phrases in user-facing text:** "Opportunity Solution Tree", "OST",
"well-formed outcome", "root of the tree", "second level", "third level",
"riskiest assumption". Use plain alternatives: "goal", "user problems we
could solve", "ideas", "the thing that has to be true for this to work".

## Step 1: Where are you starting from?

One quick multi-choice to pick the entry point.

```
Question: What do you have so far?

Options:
  1. A rough idea — I know roughly what I'd like to do but nothing is
     sharp yet
  2. A known problem — users are hitting something specific and I want
     to fix it
  3. A clear goal — I know the metric I want to move
  4. Other — I'll type it

Recommended: 1
```

Route:

- **Rough idea** → Step 2 (figure out the goal first).
- **Known problem** → skip to Step 3, but confirm the goal in one line.
- **Clear goal** → skip straight to Step 3.

Don't interrogate yet. Pick the fastest path and move.

## Step 2: What's the goal?

Ask one question, picked for the entry point. Default to the first one
below. Only ask a follow-up if the answer is thin.

```
Question: If this works, what changes in the business?

Options:
  1. A specific metric moves (conversion, churn, retention, NPS, etc.)
  2. A user behaviour shifts (more of X, less of Y)
  3. A cost or risk drops (support load, compliance, incident rate)
  4. Other — I'll describe it

Recommended: 1
```

If the user picks 1, ask for the metric as free text. Keep it to one line.

If the answer is fuzzy, try one follow-up in plain words: _"Who would notice
if this shipped — and what would they notice?"_ Don't stack three coaching
questions at once.

## Step 3: What user problems could we solve?

Help the user list 2–4 user problems (not solutions) that could move the
goal.

Distinguish problem from solution by example, not by lecture:

- Problem → "Users can't find the data they need to make decisions."
- Solution → "Build a better dashboard."

Ask:

```
Question: What do users hit that gets in the way of this goal?
Free text. List the top ones — we'll sort them in a minute.
```

If the user lists more than 5, cluster related ones together. Cap the list
at 5.

For each problem, record a short evidence tag:

- **strong** — direct user quotes, support tickets, or analytics
- **medium** — team observations or indirect signals
- **hunch** — gut feel, no data yet

You can ask this inline with multi-choice as you go through each problem,
one at a time:

```
Question: For "<problem>", what's the evidence like?

Options:
  1. Strong — users have said it or data shows it
  2. Medium — we've seen signals
  3. Hunch — it feels right but nothing hard yet
  4. Other

Recommended: 2
```

Hunches are fine — that's what experiments are for. The point is to record
honestly.

## Step 4: Quick pressure-test

Don't invoke `/grill-me`. That's a separate, heavier skill the user can run
explicitly if they want a deep stress-test. Here, a light inline check is
enough.

For each problem on the list, ask at most two short questions, picked from:

```
Question: Roughly how many users run into "<problem>"?

Options:
  1. Most users
  2. A specific segment (power users, new users, enterprise, etc.)
  3. A handful — edge case
  4. Not sure

Recommended: 2
```

```
Question: If we fix "<problem>", does the goal move?

Options:
  1. Yes, directly
  2. Probably — indirect link
  3. Unclear — we'd be guessing
  4. Other

Recommended: 1
```

Skip this step entirely for problems with strong evidence and an obvious
link to the goal. Save questions for the ones that actually need them.

If a problem turns out to be a solution in disguise ("better dashboard"),
reframe it with the user: _"That sounds like an idea — what's the user
problem it would solve?"_ Then put the idea aside for Step 6.

## Step 5: Pick one to go after first

Present the problems as a numbered list with a recommended pick. One
question, one answer.

```
Question: Which problem should we tackle first?

Options:
  1. <problem A> — strong evidence, directly moves the goal
  2. <problem B> — medium evidence, big segment
  3. <problem C> — hunch, but high ceiling if true
  4. Other — I'll describe a different framing

Recommended: <#> — <one line on why>
```

Record the pick and the reason. Note the others are deferred, not dropped —
they stay on the list for future cycles.

## Step 6: Ideas and the leap of faith

For the selected problem, brainstorm 2–4 ideas. Force multiple options
before converging — first ideas are rarely the best.

For each idea, capture:

1. **What the user would see or do** — one sentence.
2. **The leap of faith** — the one thing that has to be true for this to
   work. ("Users will actually use self-serve export" is a leap of faith.
   "Users prefer PDF over CSV" is a leap of faith.)
3. **Confidence** — ✅ high / ⚠️ medium / ❓ low.

For the leading idea, suggest a small, cheap experiment to test the leap of
faith before committing to a full build. Pick one:

- **Rough prototype** — ship a crude version to 10–20 users
- **Do it manually** — deliver the outcome by hand to a few users first
- **Fake the automation** — look automated to the user, hand-run behind the scenes
- **Check the data** — see if existing analytics already answer the question
- **Talk to users** — 5–8 conversations focused on the one assumption

Present the experiment as one line: _"Quickest way to test that users
actually want self-serve export: ship a rough version to 15 users this
sprint."_

## Step 7: Generate the diagram (silent)

Generate the Opportunity Solution Tree diagram and include it in the brief.
Do **not** narrate this step to the user. Do not ask about styling. It's an
artifact; just write it.

Mermaid `flowchart TD`:

- Goal at the top
- Problems branching from the goal
- Ideas branching from the selected problem
- Experiment at the leaf of the leading idea

Styling:

- Selected problem — blue (`fill:#e1f5fe,stroke:#0288d1`)
- Selected idea — green (`fill:#e8f5e9,stroke:#388e3c`)
- Experiment — orange (`fill:#fff3e0,stroke:#f57c00`)
- Deferred branches — grey (`fill:#f5f5f5,stroke:#bdbdbd,color:#9e9e9e`)
- Needs validation (pause/resume) — dashed border

## Step 8: Write the brief and hand off

Read `${CLAUDE_SKILL_DIR}/references/template-brief.md` for the artifact
format.

Write to `docs/discovery/{name}/brief.md`. Use a short kebab-case name
(e.g. `trial-conversion`). Create directories as needed.

Frontmatter:

- `status: complete` — all questions resolved
- `status: in-progress` — some action items are open

Before presenting:

- No `[TBD]`, `[placeholder]`, or `TODO` markers
- Decision log captures every key call with one-line rationale
- Diagram matches the decisions
- Recommendation is a single clear next step

**If complete**, tell the user:

1. Path of the brief
2. "Run `/prd` to turn this into requirements — it'll pick up context
   from the brief automatically."
3. "After building, run `/discover update {name}` to update this with what
   you learned."

**If in-progress**, tell the user:

1. Path of the brief
2. What action items are open and who needs to be consulted
3. "When you have the answers, run `/discover continue {name}` to resume."

## Pause / Resume

Discovery often spans multiple sessions. Users may need to interview
customers, check analytics, or consult stakeholders between questions.

**When the user can't answer a question:**

Don't push. Instead:

1. Log it as an action item: what needs to be learned, who to consult,
   which step it blocks
2. Continue with other questions that aren't blocked
3. When you've exhausted unblocked questions, write the brief in its
   current state with `status: in-progress`

**Resuming (`/discover continue {name}`):**

1. Read the existing brief
2. Summarize in 2–3 lines: what's decided, what's open, where we left off
3. Ask which action items the user now has answers for
4. Pick up from the right step — don't re-do settled decisions

**Updating after build/ship (`/discover update {name}`):**

1. Read the existing brief
2. Ask what was learned: did the experiment validate the leap of faith?
   Did new user problems surface? Did the goal metric move?
3. Update the diagram: mark validated/invalidated nodes, add new branches
4. Update the ideas table with PRD links and outcomes
5. If new problems emerged, the tree grows — pick the next branch

## Ground rules

- **One short question at a time.** Never stack multiple questions. Never
  present a checklist. Build on the previous answer.
- **Plain language. No framework terms in questions.** You think in the
  Opportunity Solution Tree; you speak in "goal", "user problems", "ideas",
  "leaps of faith". If the user asks what framework you're using, then you
  can name it — not before.
- **Multi-choice by default.** Only use free text for names and open
  brainstorming.
- **Non-technical throughout.** No code, architecture, APIs, or databases.
  Discovery is about users and goals.
- **Help the user think — don't just interview.** Offer ideas, suggest
  alternatives, play "what if". This is a working session, not a deposition.
- **Respect impatience.** If the user says "I already know this, let's go",
  offer a fast-track that captures the goal + selected problem + leading
  idea in three questions, and note the rest as skipped for later revisit.
- **Evidence is a spectrum.** Accept "I believe X because Y" as valid. Use
  strong/medium/hunch tags; don't demand hard data. Weak evidence is what
  experiments are for.
- **Stay in your lane.** Discovery produces strategic rationale, not
  requirements. No user stories, no acceptance criteria, no scope
  definitions — that's the PRD's job.
