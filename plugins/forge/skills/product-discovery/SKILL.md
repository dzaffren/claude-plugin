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

Guide the user through structured product discovery using the Opportunity
Solution Tree (OST) framework. The goal is to go from a fuzzy idea to a
validated opportunity with a clear outcome — before anyone writes requirements
or code.

Think of this as a coaching session. You and the user are collaborating to
figure out the right thing to build. You're not filling out a form — you're
having a conversation that progressively sharpens fuzzy thinking into a clear,
evidence-backed plan.

**Prompt style:** when a question's answer space is enumerable (outcome shape,
persona, solution type, opportunity framing), use the multi-choice pattern
from `${CLAUDE_PLUGIN_ROOT}/references/multi-choice.md` — numbered options +
"Other", a recommended choice, multi-select allowed when additive. Reserve
free text for names and genuinely open-ended brainstorming.

## Step 1: Capture the Starting Signal

Understand where the user is in their thinking. People arrive at discovery
from different starting points:

- **Vague idea** — "I think we should do something about notifications."
  The user has a hunch but hasn't articulated the problem or outcome.
  → Start at Step 2 (frame the outcome).

- **Specific problem** — "Our churn is 8% and exit surveys say 'too hard to use'."
  The user has identified a problem but may be jumping to a solution or hasn't
  framed the desired outcome.
  → Confirm the outcome framing, then go to Step 3.

- **Clear outcome** — "Increase trial-to-paid from 12% to 20% by Q3."
  The user knows the metric they want to move.
  → Validate the outcome is well-formed, then go to Step 3.

Ask just enough to figure out which entry point applies. Don't interrogate yet —
that comes later.

## Step 2: Frame the Desired Outcome (OST Root)

Read `${CLAUDE_SKILL_DIR}/references/ost-guide.md` for framework grounding.

The outcome is the root of the Opportunity Solution Tree. Everything else flows
from it. A well-formed outcome is:

- **Measurable** — tied to a specific metric (conversion rate, support tickets,
  time-to-value, retention)
- **Time-bound** — has a target timeframe
- **Within the team's influence** — the team can realistically affect it
- **Tied to business value** — stakeholders care about it

Coach the user toward a well-formed outcome. Useful questions:

- "What business metric would move if this worked?"
- "Who would notice if we shipped this successfully?"
- "If we did nothing for 6 months, what gets worse?"

If the user arrived with a clear outcome, confirm it meets the criteria and
move on. Don't over-coach when they already know where they're going.

## Step 3: Discover Opportunities (OST Second Level)

Opportunities are unmet user needs, pain points, or desires — not solutions.
This is the most common mistake in product thinking: confusing what users need
with what we plan to build. "Needs a better dashboard" is a solution. "Can't
find the data they need to make decisions" is an opportunity.

Guide the user to identify 3–5 opportunities that, if addressed, would move
the needle on the outcome. For each opportunity, push for evidence:

- What have users actually said or done that tells you this is real?
- Is there data that supports this (support tickets, analytics, user research)?
- How many users are affected, and how painful is it?

Present opportunities as a numbered list, noting evidence strength for each:

- **Strong** — direct user quotes, behavioral data, or quantitative evidence
- **Moderate** — indirect signals, team observations, or limited data points
- **Weak** — gut feeling, analogies, or assumptions without direct evidence

Weak evidence is fine — that's what experiments are for. But be honest about
the strength so the team knows what needs validation.

Cap at 5 opportunities to keep the session productive. If the user surfaces
more, help them cluster related ones.

## Step 4: Opportunity Interrogation via grill-me

Now pressure-test the identified opportunities. Run the `grill-me` skill with
these constraints:

**Restrict all questions to opportunity validation** — the audience is a
product owner or PM, not an engineer.

Ask about:

- Evidence quality — are the opportunities based on real user data or assumptions?
- Opportunity sizing — how many users, how often, how painful?
- Outcome linkage — if we solve this opportunity, does the outcome actually move?
- User segment specificity — who exactly has this problem? Everyone, or a niche?
- Opportunity vs. solution confusion — is this really a need, or a disguised solution?
- Interdependencies — does solving one opportunity depend on or unlock another?

Do NOT ask about:

- Technical feasibility, architecture, or implementation
- Specific features or solution designs (that comes in Step 6)
- Code, APIs, databases, or system design

## Step 5: Prioritize and Select

Help the user pick **one opportunity** to pursue first. This is a Teresa Torres
principle: focus beats breadth. You can always come back for the others.

Evaluate each opportunity against:

- **Size** — how many users are affected, how painful is the problem
- **Evidence strength** — how confident are we this is real
- **Outcome alignment** — how directly does this connect to the desired outcome
- **Feasibility** — does the team have the ability to address this (without
  getting into technical specifics)

Make the selection explicit: "Based on what we've discussed, Opportunity #X
looks like the strongest candidate because..." Record the rationale.

Acknowledge what's being deferred — not discarded. The other opportunities
remain on the tree for future cycles.

## Step 6: Solutions and Assumptions (OST Third/Fourth Levels)

For the selected opportunity, brainstorm 2–4 possible solutions. The key
discipline here is generating multiple options before converging — combat the
"first idea is the only idea" trap.

For each solution candidate:

1. **Describe it concretely** — what would the user experience?
2. **Identify the riskiest assumption** — the thing that must be true for this
   solution to work. "Users will actually use self-serve export" is an
   assumption. "Users prefer PDF over CSV" is an assumption.
3. **Rate confidence** — how sure are we this assumption holds?

For the leading solution (or the one the user is most excited about), suggest
a **lightweight experiment** to test the riskiest assumption before committing
to a full build:

- **Prototype test** — build a rough version and put it in front of 10–20 users
- **Concierge test** — manually deliver the solution to a few users
- **Wizard of Oz** — fake the automation, do it by hand behind the scenes
- **Data analysis** — check if existing data already answers the question
- **User interviews** — talk to 5–8 users specifically about this assumption

The experiment should be something the team can run in days, not weeks.

## Step 7: Build the Opportunity Solution Tree Diagram

Generate a Mermaid `flowchart TD` visualizing the full OST from the session:

- Outcome at the top
- Opportunities branching down from the outcome
- Solutions branching from the selected opportunity
- Experiment at the leaf of the leading solution

Use styling to communicate status:

- **Selected opportunity** — blue highlight (`fill:#e1f5fe,stroke:#0288d1`)
- **Selected solution** — green highlight (`fill:#e8f5e9,stroke:#388e3c`)
- **Experiment** — orange highlight (`fill:#fff3e0,stroke:#f57c00`)
- **Deferred branches** — grey (`fill:#f5f5f5,stroke:#bdbdbd,color:#9e9e9e`)
- **Needs validation** (for pause/resume) — dashed border

Include the diagram in the discovery brief.

## Step 8: Write Discovery Brief and Hand Off

Read `${CLAUDE_SKILL_DIR}/references/template-brief.md` for the artifact format.

Write the discovery brief to `docs/discovery/{name}/brief.md` at the repo root,
creating directories as needed. Use a kebab-case name derived from the outcome
or opportunity (e.g., `docs/discovery/trial-conversion/brief.md`).

Set the frontmatter:

- `status: complete` if all questions are resolved
- `status: in-progress` if action items remain

Validate before presenting:

- No `[TBD]`, `[placeholder]`, or `TODO` markers
- Decision log captures all key decisions with rationale
- OST diagram matches the decisions made
- Recommendation is a clear next step

**If complete**, tell the user:

1. The path of the discovery brief
2. Recommend: "Run `/prd` to turn this into product requirements — it will
   pick up context from this brief automatically"
3. Remind: "After building, run `/discover update {name}` to update the tree
   with what you learned"

**If in-progress**, tell the user:

1. The path of the saved brief
2. What action items are open and who needs to be consulted
3. Recommend: "When you have the answers, run `/discover continue {name}`
   to pick up where we left off"

## Pause / Resume

Discovery often spans multiple sessions. The user may need to interview
customers, check analytics, or consult stakeholders between questions.

**When the user can't answer a question:**

Don't push. Instead:

1. Log it as an **action item**: what needs to be learned, who to consult,
   and which step it blocks
2. Continue with other questions that aren't blocked
3. When you've exhausted unblocked questions, write the brief in its current
   state with `status: in-progress`

**Resuming (`/discover continue {name}`):**

1. Read the existing brief at `docs/discovery/{name}/brief.md`
2. Summarize: what's been decided, what action items were open, where in the
   process you left off
3. Ask which action items the user now has answers for
4. Resume from the appropriate step — don't re-do settled decisions

**Updating after build/ship (`/discover update {name}`):**

1. Read the existing brief
2. Ask what was learned: Did the experiment validate the assumption? Did new
   opportunities emerge? Did the outcome metric move?
3. Update the OST diagram: mark validated/invalidated nodes, add new branches
4. Update the Solution Candidates table with PRD links and outcomes
5. If new opportunities emerged, the tree grows — pick the next branch

## Ground Rules

- **One question at a time.** Build on answers. Don't present a checklist.
- **Non-technical language throughout.** No code, architecture, APIs, or
  databases. Discovery is about users and outcomes.
- **Generative, not just interrogative.** Help the user think — offer ideas,
  suggest alternatives, play "what if." This is brainstorming, not a deposition.
- **Respect impatience.** If the user says "I already know the problem, let's
  go," offer a fast-track that still captures the outcome and key assumptions.
  Note what was skipped so they can revisit if needed.
- **Evidence is a spectrum.** Accept "I believe X based on Y" as valid. Note
  assumption strength (strong/moderate/weak) rather than demanding hard data.
  Weak evidence is what experiments are for.
- **Stay in your lane.** Discovery produces strategic rationale, not requirements.
  Don't write user stories, acceptance criteria, or scope definitions — that's
  the PRD's job.
