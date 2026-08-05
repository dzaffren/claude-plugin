---
name: poc
description: >
  Builds a throwaway spike to answer the riskiest assumption before the real
  design is committed to. Use between /discover and /refine, when a discovery
  brief names an experiment, or when the user says "spike this", "poc",
  "prototype it", "can this even work". The code is disposable by contract;
  only the answer survives.
---

# PoC

Answer one question with the dirtiest code that can answer it. A spike is an
experiment, not a first draft — the deliverable is the answer, never the code.

## Steps

1. **Name the question.** One sentence, falsifiable: "Can the export finish
   under 5s for 100k rows?", "Does the vendor API support partial updates?"
   Pull it from the discovery brief's experiment if one exists; otherwise
   agree it with the user first — never invent the question or its stakes
   yourself (use AskUserQuestion). The question can test **feasibility**
   ("can this work?") or **desirability** ("will users want or grasp this?");
   a desirability spike is usually a rough clickable mockup, and that mockup
   is the artifact you put in front of stakeholders. No question, no spike.

2. **Set the kill criteria.** Before writing code: what result means yes,
   what means no, and a time box. When the box runs out, the answer is
   "unknown — and here's what it would take to find out."

3. **Spike on a throwaway branch** named `poc/{name}`. Explicitly exempt
   from all quality rules: hardcode, stub, skip tests, ignore style. Do NOT
   touch shared code paths in ways that would be painful to revert — the
   branch gets deleted, never merged.

4. **Record the answer, kill the code.** Write the result into the
   discovery brief (or spec, if one exists): question, what was tried, the
   answer with the actual evidence (numbers, output, error messages), and
   what it changes about the design. Then delete
   the branch (`git branch -D poc/{name}`) — or, if the user wants to keep it
   (a desirability mockup to demo to stakeholders, or just for reference), say
   plainly that nothing on it is merge-quality and it is not the real design —
   `/design` builds that on an approved spec.

5. **Capture the lesson** (learn skill) if the spike surfaced something a
   future run would otherwise rediscover the hard way.

Hand off: answer favorable → `/spec` or `/refine` with the new knowledge.
Unfavorable → back to `/discover` to pick the next solution candidate.
