---
name: refine
description: >
  Adds the technical plan to an approved spec: architecture, data changes,
  interfaces, test strategy, risks. Use after /spec is approved, when the user
  says "refine the spec", "technical requirements", "how do we build this",
  or for small technical tasks that need no product spec at all. Updates the
  spec .md and its HTML visualization, then stops for approval before /build.
---

# Refine

Turn an approved spec into a buildable technical plan. This is where
implementation detail belongs — file paths, endpoints, schemas, real function
names. Works standalone for obvious bugs, refactors, and upgrades that never
needed a product spec; in that case create the spec file fresh with a short
Problem section and go straight to the technical plan.

## Steps

1. **Read the spec** in `docs/specs/` (ask which if ambiguous) and confirm it
   is approved. Read the acceptance criteria carefully — the plan must cover
   every scenario. If the spec has a `## Design` section, the approved
   component list is the default **Chunks** split; if the spec has UI scope
   but no Design section, suggest `/design` first.

2. **Read the code first.** Trace the real path the change touches, with file
   and line references. Find the helpers, patterns, and tests that already
   exist — the plan must reuse them, not invent parallels. Note the project's
   real commands (test, lint, build) from `package.json` / `pyproject.toml` /
   `Makefile` / CI config.

3. **Interrogate, technically this time.** Pressure-test the design before
   writing it down: failure modes, migration/rollback, concurrency, authz
   boundaries, what breaks downstream. The code answers what it can; for
   everything else — trade-offs, priorities, acceptable risk, anything the
   files can't prove — never assume: ask via AskUserQuestion and wait for the
   answer before it goes in the plan.

4. **Append a `## Technical plan` section** to the same spec file:
   - **Approach** — two or three sentences, then a Mermaid diagram of the
     components touched, arrows labeled with what moves between them.
   - **Changes** — per file or module: what changes and why, referencing
     existing code as `path/file.py:42`. Name the existing helpers being
     reused.
   - **Data / interface changes** — schemas, endpoints, contracts, migrations
     and their rollback.
   - **Test plan** — which unit/integration/e2e tests prove each acceptance
     scenario, and the exact commands to run them.
   - **Chunks** — how /build splits the work for parallel agents: each
     chunk lists its acceptance scenarios and the files it owns. Files must
     be disjoint between chunks — ownership is what makes parallel building
     safe. Split along the module boundaries found in step 2. Small change
     that doesn't split → write `Single chunk`.
   - **Risks** — real ones only, each with its mitigation. No filler.
   - Simplest thing that works. No new abstraction, config, or layer the
     acceptance criteria don't demand.

5. **Render and stop.** Set the spec's Status to `Refined`, regenerate the
   HTML view (spec-html skill), and refresh the index
   (`md2html.py --index docs/specs`). Tell the
   user what the plan's riskiest choice is in one line, say `/build` is next
   once they approve, and end with the `file://` link on its own line. Do NOT
   start coding.
