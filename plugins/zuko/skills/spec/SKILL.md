---
name: spec
description: >
  Writes the full spec for one vertical slice — scope and acceptance
  criteria, the interface, then the technical and ship plan — pausing three
  times for approval. Use after /shape picks a slice, or directly when the
  user says "spec this", "write the requirements", "how do we build this",
  or describes one concrete piece of work. Produces docs/specs/{slice}.md
  plus a published visual page.
disable-model-invocation: false
---

# Spec

One slice, one spec, three pauses. At the end the slice is ready to build with
nothing unresolved.

Read these before starting:
`${CLAUDE_PLUGIN_ROOT}/references/voice.md`,
`${CLAUDE_PLUGIN_ROOT}/references/slicing.md`,
`${CLAUDE_PLUGIN_ROOT}/references/diagram-set.md`,
`${CLAUDE_PLUGIN_ROOT}/references/ledger.md`.

**Never assume.** Anything unknown is either asked or written into the ledger
as an assumption. Never a silent guess.

## Before pause 1 — orient

- Read the shape doc in `docs/specs/{idea}/shape.md` if there is one, and
  carry its problem, project type, and ledger forward.
- Read `CLAUDE.md`, `docs/learnings/`, and the related code.
- Check for an existing spec of this name and apply the versioning rules
  (bottom of this file).
- Decide **full path or light path** using the rules in `slicing.md`. Say
  which and why in one line. On the light path, merge pauses 1 and 3, skip
  pause 2, and say so.

Copy `${CLAUDE_SKILL_DIR}/references/spec-template.md` as the shape of the
file. Delete every section that does not apply — never leave an empty
heading or a `{placeholder}`.

## Pause 1 — scope and acceptance

**Greenfield slice 0.** If this is a walking skeleton, the stack is not yours
to choose. Ask, one at a time: language and framework, database, host and
deploy target, CI, test runner and e2e tool, package manager. Record every
answer in the spec — it is the decision record for the whole project.

**Interrogate, product-side only.** Before writing anything: edge cases,
business rules, what counts as done, what happens on failure, who is allowed.
No architecture questions — those are pause 3.

**Run the slice test** and write the four results into the spec. Fails any
check → split now and say what the sibling slices are. Never widen the spec
to make it pass.

**Write:**

- Problem, in the user's terms.
- User story, if there is a user.
- The user flow diagram (or caller flow for non-UI). A state diagram when the
  thing has distinct states.
- Acceptance criteria in Given/When/Then, covering the happy path, the errors
  the user will actually hit, and the edge cases that matter. Real names, real
  dates, real quantities — never `foo` or `user1`.
- Scope in and out, and which later slice picks up each out-of-scope item.
- The ledger, updated.

**Then stop.** Show the diagram, the scenarios, the slice test result, and any
open items. Ask for approval. Do not continue.

## Pause 2 — the interface

Skip entirely on the light path. Skip when the slice has no interface at all.

This is the interface stage, not the pixels stage. What it covers depends on
the project type — see the table in `slicing.md`:

| Project type | Design here |
|---|---|
| Web UI | screens, states, motion |
| API / service | endpoint shape, payloads, status codes, error bodies |
| CLI / library | command surface, flags, output format, help text, errors |
| Data / LLM app | input and output contract, prompt shape, failure modes |

### For web UI

1. **Read `${CLAUDE_PLUGIN_ROOT}/references/craft.md` in full.** The bans and
   the floors are not optional.

2. **The design system must exist.** Look for it: a Claude Design project via
   DesignSync `list_projects`, then `components.json`, a tokens or theme file,
   `tailwind.config`. `list_projects` answering that it needs authorization is
   not "found nothing" — ask the user to run `/design-login` and look again.
   Found nothing → **stop and send the user to `/design system`.** No system,
   no screens. This gate is what keeps every component standardised.

3. **Compose only.** Assemble screens from the system's existing primitives
   and tokens. Needs something the system lacks → stop and offer the two
   options from `craft.md`: add it to the system deliberately, or rework the
   screen. Never invent a one-off.

4. **Pick the motion tier** with the user. Tier 3 needs its written budget in
   the spec before it passes.

5. **Load the craft chain**, whichever are installed, in this order:
   `frontend-design` (official) → `design-taste-frontend` → `shadcn` when the
   repo uses it. None installed → `craft.md` alone is enough.

6. **Build the preview.** Two levels — pick automatically:
   - **The repo has a runnable dev server** → build the real components in
     the repo behind a preview route. `/build` then inherits working UI
     instead of throwing the design away.
   - **Otherwise** → one self-contained file at
     `docs/design/{slice}/preview.html` holding every screen, with real CSS
     and real motion. One file, one link.

   Either way, show every state the acceptance criteria mention: default,
   hover, focus, empty, loading, error.

7. **Run the drift check before showing anything**, passing the paths this
   run actually wrote:

   ```
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-design-drift.sh" <paths>
   ```

   The paths matter. Called with no argument it only looks at `docs/design`,
   so on the dev-server path — where the components went into `src/` or
   `app/` — it would scan nothing. It exits 1 rather than passing silently
   when that happens, but the fix is to pass the paths. It fails → fix and
   re-render. The user only ever sees previews that already conform.

8. **Run the two checks from `craft.md`** — the generic-model test and the
   named-reference test. Failing either means revise, not ship.

9. Offer a Claude Design canvas when the layout is unsettled and the user
   would rather drag than describe. A canvas is published, not synced —
   `/design-sync` pushes a design system and does not make one. Motion does
   not play on a canvas — say so.

### For every project type

Write the Interface section: what was designed, the components used (names
from the system only), the motion tier, and the preview path.

**Then stop.** Give the preview link and name which design system the tokens
came from. Design review is a loop — when the user wants changes, edit and
stop again. Do not continue to pause 3 until approved.

## Pause 3 — technical and ship plan

**Read the code first.** Trace the real path this change touches, with file
and line references. Find the helpers, patterns, and tests that already exist
— the plan reuses them rather than building parallels. Note the project's
real commands from `package.json` / `pyproject.toml` / `Makefile` / CI config.

**Interrogate, technically.** Failure modes, concurrency, authz boundaries,
what breaks downstream, migration and rollback. The code answers what it can.
For trade-offs and acceptable risk, ask — never assume.

**Spot the unproven.** Any claim the plan rests on that nobody has verified —
"this API supports that", "this will be fast enough", "this library handles
our load" — is an `unproven` ledger row, and you offer `/poc` to settle it
before writing the plan as fact. Do not write a confident plan on a guess.

**Write the Technical plan section** per the template:

- **Approach** — a few sentences, an architecture diagram, and a sequence
  diagram of the main runtime path. Data flow diagram when data crosses a
  trust or system boundary.
- **Changes** — per file, what changes and why, referencing real code as
  `path/file.ts:42`. Name the helpers being reused.
- **Data** — ER diagram when the schema changes. Schema changes follow
  **expand → backfill → switch**; the contract step is a later slice, never
  this one. Write the exact reverse path, and it must be tested.
- **Earn-it** — every new layer, service, abstraction, config option, cache,
  queue, or dependency names the acceptance criterion or risk that demands
  it. Cannot name one → cut it.
- **Non-functionals** — the five-line block. Load, what breaks first at 10×,
  the security surface (who can call it, what input it trusts, what secrets
  it touches, what data it stores), the exact log line or metric that proves
  it works in prod, and the rollout with its flag and rollback path.
- **Test plan** — which test proves each scenario, with exact commands. Name
  the one e2e test that walks the whole slice. **No e2e harness in the repo?**
  Setting it up is explicit work in this plan, not an assumption.
- **Chunks** — how `/build` splits it. Files disjoint between chunks; shared
  files (types, barrel exports, lockfiles) belong to one chunk only. Small
  change → `Single chunk`.
- **Risks** — real ones with mitigations. No filler.

**Publish the visual page** per
`${CLAUDE_PLUGIN_ROOT}/references/visual-page.md`.

**Then stop.** Set Status to `Refined`. Give the spec path, the page link, and
the plan's riskiest choice in one line. Print the ledger. Say `/build` is next.
Do not write code.

## Versioning

`docs/specs/{slice}.md` already exists:

- Status `Shipped` → new iteration. `git mv` the old file to
  `docs/specs/archive/{slice}-v{N}.md`, write the new one as `v{N+1}` with a
  `**Supersedes:**` line. Carry the ledger forward.
- Any other status → still in flight. Update it. Never fork a second spec for
  the same slice.

## Resuming

`/spec continue {slice}` — read the file, print the open ledger rows first,
then what is settled and what is open in a few lines. Ask which open items now
have answers. Edit the existing file. Settled sections stay settled unless the
user reopens them.

## Migrating an old shipwright spec

A spec with a `## Technical plan` but no `## Open items` or `## Slice test`
came from shipwright. Offer to migrate it: add the missing sections, run the
slice test, and say plainly if the old spec is actually several slices.
Never rewrite its content silently.
