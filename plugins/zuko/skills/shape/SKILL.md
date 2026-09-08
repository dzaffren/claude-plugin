---
name: shape
description: >
  Turns a rough idea into a stated problem and an ordered list of shippable
  vertical slices. The front door of the zuko workflow. Use when the user has
  an idea, a vague want, a "wouldn't it be good if", a problem with no
  solution yet, or says "shape this", "what should we build", "where do I
  start". Produces docs/specs/{idea}/shape.md, then stops.
disable-model-invocation: false
---

# Shape

Take something half-formed and turn it into work that can be started. The
output is a problem worth solving plus an ordered list of slices, each one
shippable on its own.

Read `${CLAUDE_PLUGIN_ROOT}/references/voice.md` before writing anything.

**Never assume.** Every claim in the shape doc comes from the user or the
codebase. When something is unknown, either ask, or write it into the ledger
as an assumption. A silent guess here becomes a wrong spec later.

## Steps

### 1. Understand the idea

Ask, one question at a time, until you can state the problem in two sentences
without hedging:

- What made you think of this? What happened?
- Who has this problem, and how often?
- What do they do today instead?
- What does it cost them — time, money, mistakes, frustration?
- How would you know this worked?

Stop asking when you can write the problem down and the user would recognise
it. Usually three to five questions. Do not run a workshop.

### 2. Read the ground

- The repo's `CLAUDE.md` and `README`.
- `docs/specs/` for overlapping or related work.
- `docs/learnings/` for lessons that apply.
- Enough code to know what already exists. Do not design anything yet.

Determine the **project type** (see
`${CLAUDE_PLUGIN_ROOT}/references/slicing.md`): web UI, API/service,
CLI/library, or data/LLM app. Detect it from the repo. Ask only if genuinely
ambiguous. Write it down — every later stage reads it.

**Empty or near-empty repo** → this is a greenfield build. Say so plainly.
Slice 0 will be a walking skeleton, and it needs stack decisions at `/spec`.
Do not pick a stack here.

### 3. Write the problem

Two sentences, no hedging, no solution in them. Then a context diagram: who
touches what today, and where the pain is.

If you cannot write the problem without naming the solution, you do not
understand it yet. Go back to step 1.

### 4. Find the slices

This is the real work. Read
`${CLAUDE_PLUGIN_ROOT}/references/slicing.md` in full before doing it.

Split along what a user can do, never along what the system has. Each slice
must pass the slice test on its own. Order them so that:

- the first one is the smallest thing that is genuinely worth shipping
- each later one works whether or not the ones after it ever get built
- anything that unblocks several others comes early

Then draw the slice map — the slices, their order, and any real dependency
between them.

For a greenfield build, slice 0 is the walking skeleton and comes first.

Sanity check: if you have more than about six slices, you are either
splitting too fine or the idea is two ideas. Say which.

### 5. Open the ledger

Start the ledger (`${CLAUDE_PLUGIN_ROOT}/references/ledger.md`). Every
unknown that came up, and every assumption you made to keep moving, gets a
row. Nothing silent.

### 6. Write it and stop

Write `docs/specs/{idea}/shape.md`:

```markdown
# {Idea}

**Project type:** {…} · **Status:** Shaped

## Problem
{two sentences}

## Today
{context diagram + one sentence}

## Slices
{slice map diagram}

| # | Slice | What ships | Why this order |
|---|-------|-----------|----------------|
| 1 | … | … | … |

## Not doing
{what was considered and rejected, with the reason}

## Open items
{the ledger table}
```

Then, in the terminal:

- The problem, in two sentences.
- The slice list with the diagram.
- Open items, if any.
- **If the project type is web UI and no design system exists** — say so:
  `/design system` should run once, before the first UI slice, and takes
  roughly half an hour. Do not start it.
- Ask which slice to spec first. Recommend one and say why.

STOP. Do not write a spec. Do not write code.

## Resuming

`/shape continue {idea}` — read the existing doc, print what is settled and
what is open in a few lines, ask which open items now have answers, then edit
the file. Settled sections stay settled.
