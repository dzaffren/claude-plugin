---
name: spec
description: >
  Writes a product spec (requirements document) before any technical design or
  code. Use when the user wants to define requirements, describe a feature,
  write up a bug, or says "spec this", "write the requirements", "PRD this".
  Reads the codebase for grounding but the output is non-technical. Produces
  docs/specs/{name}.md plus an HTML visualization, then stops for the user's
  approval before /refine.
---

# Spec

Write a requirements document a stakeholder can review and approve before any
engineering time is spent. Use codebase knowledge to keep it realistic, but
keep implementation detail out of the output — no file paths, endpoints,
tables, or code identifiers.

**Never assume.** Every requirement in the spec must come from the user or the
codebase, not from a guess. When something is unknown — scope, audience, an
edge-case rule, what "done" means — ask via AskUserQuestion before writing it
down. A spec with a wrong assumption baked in is worse than a session with one
more question.

## Steps

1. **Gather the basics.** Feature name (kebab-case), scope (bug / small
   enhancement / feature / multi-story epic), who it's for, the problem, how
   success is measured, what's in and out. Ask about anything unclear before
   writing — one question at a time.

2. **Load context.** Read the repo's `CLAUDE.md`. Check
   `docs/discovery/` for a related brief — if one exists, pre-load its
   outcome, picked opportunity, and solution direction, and reference it near
   the top of the spec. Check `docs/specs/` for overlap. Skim related code to
   understand real system boundaries (this shapes scope and story splits, not
   the wording).

3. **Interrogate.** Before writing, pressure-test the requirements with
   product questions only: edge cases and business rules, scope trade-offs,
   success metrics, rollout risks. No architecture or implementation
   questions — those belong to /refine.

4. **Version, don't jumble.** If `docs/specs/{name}.md` already exists:
   - Status `Shipped` → this is a new iteration. Move the old file to
     `docs/specs/archive/{name}-v{N}.md` (git mv, delete its stale `.html`),
     then write the new spec as `Version: v{N+1}` with a
     `**Supersedes:** archive/{name}-v{N}.md` line.
   - Any other status → the work is still in flight. Update the existing
     file; never fork a second spec for the same feature.

5. **Write the spec** to `docs/specs/{name}.md` following
   `${CLAUDE_SKILL_DIR}/references/spec-template.md`. Rules:
   - User-facing features get a user story ("As a…, I want…, so that…").
     Bugs and technical tasks don't.
   - Acceptance criteria in Given/When/Then, covering happy paths, errors,
     and edge cases. Concrete examples with realistic names, dates, values.
   - A Mermaid diagram of the user journey or main flow — this is the
     visualization the user reviews, so make it carry the story. Add a
     `stateDiagram-v2` of the thing's lifecycle when the feature has distinct
     states the user moves it through (draft → submitted → paid); delete it
     when there are none. Keep every diagram under ~10 boxes — two at
     different zoom levels beat one dense one.
   - No placeholders, no `[TBD]` except ticket IDs, no empty sections —
     delete what doesn't apply.
   - For a genuine multi-story epic: `docs/specs/{name}/spec.md` overview
     plus one `spec-{story}.md` per story, each independently valuable.
     Never wrap a single spec in a directory.

6. **Render and stop.** Generate the HTML view (spec-html skill) and refresh
   the index (`md2html.py --index docs/specs`). Tell the
   user the spec path, ask them to review the visual plan, and say the next
   step is `/refine` once they approve. Do NOT start technical design or code.
   End with the `file://` link on its own line.

## Resuming (`/spec continue {name}`)

When a Draft spec for the topic already exists, don't start over: read it,
summarize what's settled and what's open in a few lines, ask which open
questions now have answers, and edit the existing file. Settled sections
stay settled unless the user reopens them.
