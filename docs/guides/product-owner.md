# Product Owner Guide

This guide covers the skills product owners use to discover opportunities, define requirements, and validate thinking before engineering work begins.

## Your Workflow

```
/discover → /prd my-feature → grill-me interrogation → approved PRD → hand off to engineer
               ↕ /poc                    ↕ /poc
         (validate solution)          (validate UX)
```

1. Run `/discover` to validate you're solving the right problem (optional but recommended)
2. Run `/poc` to show stakeholders what the solution could look like — great after discovery before committing to a PRD (optional)
3. Run `/prd` to generate a product requirements document
4. Answer the interrogation questions (powered by `/grill-me`)
5. Run `/poc` again to validate the UX with stakeholders before engineering starts (optional)
6. Review and approve the PRD
7. Hand off to an engineer who runs `/prd-refine` then `/build`

---

## /discover — Product Discovery

Guides structured product discovery using the Opportunity Solution Tree (OST) framework. Takes you from a fuzzy idea to a validated opportunity with a clear outcome — before anyone writes requirements.

### When to Use

- You have a vague product idea and want to figure out what to build
- You want to validate you're solving the right problem before writing a PRD
- You need to brainstorm opportunities and narrow down to one worth pursuing
- You want a structured way to go from "we should do something about X" to a concrete plan
- Before any non-trivial feature work, to make sure the "why" is clear

### Usage

```
/discover
```

Then describe your idea, problem, or goal. The skill adapts to where you are in your thinking:

- **Vague idea** — "I think we should do something about notifications" → full coaching from outcome framing onwards
- **Specific problem** — "Our churn is 8% and exit surveys say 'too hard to use'" → confirms framing, then explores opportunities
- **Clear outcome** — "Increase trial-to-paid from 12% to 20% by Q3" → validates quickly, jumps to opportunity discovery

### How It Works

1. **Capture starting signal** — Understands where you are and adapts the session
2. **Frame the outcome** — Coaches toward a measurable, time-bound business outcome (skipped if you arrive with one)
3. **Discover opportunities** — Brainstorms 3–5 unmet user needs with evidence strength (strong/moderate/weak)
4. **Interrogate opportunities** — Pressure-tests via `/grill-me` — challenges evidence quality, sizing, and opportunity-vs-solution confusion
5. **Prioritize and select** — Picks ONE opportunity to pursue with explicit rationale
6. **Solutions and assumptions** — Brainstorms 2–4 solutions, identifies the riskiest assumption for each, suggests a lightweight experiment
7. **Build OST diagram** — Generates a Mermaid flowchart showing the full tree with the selected path highlighted
8. **Write discovery brief** — Saves to `docs/discovery/{name}/brief.md` with a handoff recommendation to `/prd`

### Pause and Resume

Discovery rarely finishes in one sitting. When you need to check analytics, talk to users, or consult stakeholders:

- Say "I need to check on that" — Claude logs it as an action item and saves your progress
- The brief is written with `status: in-progress` and an action items table
- Come back later and say `/discover continue {name}` to pick up where you left off
- After building and shipping, run `/discover update {name}` to update the tree with what you learned

### Output

Discovery briefs are written to:

```
docs/discovery/{name}/brief.md
```

Each brief includes: desired outcome, opportunity map with evidence, selected opportunity with rationale, solution candidates, Mermaid OST diagram, recommended experiment, decision log, and open questions.

### Tips

- This is a coaching conversation, not a form — one question at a time, building on your answers
- Evidence doesn't have to be hard data. "I believe X based on Y" is valid — the skill notes assumption strength
- If you already know the problem, say so — the skill respects impatience and offers a fast track
- Each solution from the brief can become its own PRD — the linkage is automatic
- The brief stays non-technical throughout — no code, no architecture, no APIs

### Next Step

When discovery is complete:

```
/prd my-feature    # Picks up context from the discovery brief automatically
```

---

## /prd — PRD Generator

Generates a product requirements document from a feature request or problem statement. The output is non-technical — readable by anyone without engineering knowledge.

### When to Use

- You have a feature idea that needs to be shaped into requirements
- You want to define what needs to be built before engineering starts
- You need to capture product needs, business rules, and acceptance criteria
- You want to scope out work from a business perspective

### Usage

```
/prd <feature-name>
```

Examples:

```
/prd add-user-notifications
/prd PROJ-123-checkout-flow
/prd billing-dashboard
```

### How It Works

1. **Extract details** — Claude asks for the feature name, ticket number, scope (bug/enhancement/feature/epic), target user, and business problem
2. **Prerequisites gate** — Confirms enough context exists: what it does, who it's for, how success is measured, what's in/out of scope
3. **Context loading** — Reads `CLAUDE.md`, `docs/architecture.md`, and existing code to understand system boundaries. If a discovery brief exists in `docs/discovery/`, pre-loads the outcome, selected opportunity, and chosen solution as context (this happens behind the scenes — the output stays non-technical)
4. **Interrogation** — Runs `/grill-me` to stress-test the requirements. Questions focus on user needs, business rules, edge cases, scope trade-offs, and story decomposition
5. **Template selection** — Picks the right template based on scope:
   - Bug report
   - Small enhancement (< 1 day)
   - Single feature (user-facing)
   - Single task (technical)
   - Multi-story epic
6. **Fill template** — Writes the PRD with Gherkin acceptance criteria (Given/When/Then)
7. **Validate** — Checks for completeness: no placeholders, concrete examples, thorough acceptance criteria
8. **Handoff** — Tells you the file path and recommends running `/prd-refine` next

### Output

PRD files are written to:

```
docs/specs/{ticket}-{name}/spec.md
```

For multi-story epics:

```
docs/specs/{ticket}-{name}/
├── spec.md                    # Epic overview
├── spec-story-one.md          # Story 1
├── spec-story-two.md          # Story 2
└── ...
```

### Epic Support

For multi-story epics, `/prd` writes the epic overview itself, then spawns `prd-story-writer` agents in parallel — one per story. Each agent writes a single story PRD aligned with the epic boundaries. After all agents finish, Claude verifies consistency across stories.

### Tips

- Provide a ticket number if you have one — it gets used in the file path
- Be clear about scope upfront: is this a bug, a small fix, a feature, or an epic?
- Engage with the interrogation — it surfaces edge cases and scope gaps you haven't considered
- The PRD stays non-technical even though Claude reads the codebase behind the scenes
- For epics, stories are split vertically based on actual system boundaries

### Next Step

After the PRD is approved, hand it off to an engineer:

```
/prd-refine <feature-name>    # Adds technical detail
/build <feature-name>          # Implements the spec
```

---

## /poc — Proof of Concept Prototype

Generates a clickable HTML/CSS/JS prototype to show stakeholders what a feature could look like — before requirements are written or engineering starts. No build tools, no deployment: just files you open in a browser and share.

### When to Use

- **After `/discover`** — to validate the chosen solution direction with stakeholders before investing in a PRD
- **After `/prd`** — to validate the UX and flow before handing off to engineering
- Any time you want to show rather than describe — stakeholder reviews, user interviews, pitch decks

### Usage

```
/poc <feature-name>
```

Examples:

```
/poc notifications-redesign
/poc user-onboarding
/poc checkout-flow
```

If a discovery brief or PRD exists for the feature, it's loaded automatically as context.

### How It Works

1. **Clarify scope** — Asks which screens to cover and how interactive the prototype should be (unless you've already described them)
2. **Load context** — Reads your discovery brief (`docs/discovery/`) and/or PRD (`docs/specs/`) if they exist; falls back to your description
3. **Plan screens** — Maps out each screen, its purpose, and navigation flow; confirms with you for complex prototypes before building
4. **Generate prototype** — Writes self-contained HTML files with Tailwind styling and realistic mock data
5. **Validate** — Traces through every user journey to check links, interactions, and data consistency
6. **Handoff** — Tells you which file to open and recommends the next step

### Interactivity Levels

| Level                | What it does                                                                                                  |
| -------------------- | ------------------------------------------------------------------------------------------------------------- |
| **Clickthrough**     | Screens linked by navigation only — good for validating flow                                                  |
| **Interactive**      | Forms, modals, toggles, and UI state driven by mock data                                                      |
| **Full walkthrough** | Realistic end-to-end flow where actions update the UI (form submits add rows, approvals change status badges) |

You choose the level — or describe what you want and the skill picks the right one.

### Output

Prototype files are written to:

```
docs/poc/{name}/
├── index.html          # Entry point — open this first
├── {screen}.html       # One file per additional screen
└── ...
```

Every file is fully self-contained — open any of them directly in a browser, no server needed.

### Tips

- If you already have a PRD or discovery brief, the skill reads it automatically — you don't need to describe the feature again
- Describe any specific flows or edge cases you want stakeholders to see (error states, empty states, key decision points)
- Prototypes use realistic fictional data (real-looking names, dates, amounts) — this makes stakeholder reviews much more productive than placeholder text
- After review, use stakeholder feedback to update the PRD before handing off to engineering

### Next Steps

After validating with stakeholders:

```
/prd <feature-name>           # If you ran /poc after /discover
/prd-refine <feature-name>    # If you ran /poc after /prd and are ready for technical detail
```

---

## /grill-me — Design Interrogation

Interactive interrogation that walks every branch of a design decision tree until reaching shared understanding. Used automatically by `/prd`, but also available standalone.

### When to Use

- You have a plan or design you want stress-tested
- You want to surface edge cases and unresolved decisions
- You're unsure about scope boundaries or trade-offs
- Before any non-trivial work, to validate your thinking

### Usage

```
/grill-me
```

Then describe your plan or design in the conversation.

### How It Works

- Asks questions **one at a time**, resolving dependencies between decisions
- For each question, provides its own **recommended answer** so you can agree, disagree, or refine
- If a question can be answered by **exploring the codebase**, it does so instead of asking you
- Walks down each branch of the design tree systematically

### Example Session

```
You: /grill-me
     I want to add email notifications when users complete checkout

Claude: What triggers the notification — the payment confirmation or the
        order creation? My recommendation: payment confirmation, since
        that's when the user's transaction is finalized.

You: Payment confirmation, agreed.

Claude: Should failed payments also trigger a notification?
        My recommendation: Yes — users should know if payment failed
        so they can retry.
...
```

### Tips

- Be honest about what you don't know — that's what the interrogation is for
- It's okay to disagree with Claude's recommendations
- The interrogation ends when all branches are resolved, not after a fixed number of questions
- When used inside `/prd`, questions are restricted to product/business concerns only
