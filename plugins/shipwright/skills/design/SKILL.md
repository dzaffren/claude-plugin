---
name: design
description: >
  UI/UX design stage between /spec and /refine, for specs with a frontend.
  Use when an approved spec has screens or components to design, or when the
  user says "design the UI", "mockups", "what should this look like".
  Produces real rendered HTML component previews, synced to a Claude Design
  project for visual review when available. Approved components become the
  chunk boundaries for /build.
---

# Design

Turn an approved spec's UI scope into rendered components the user reviews
visually — real HTML, not descriptions of HTML. Skip this stage entirely for
specs with no frontend.

## Steps

1. **Read the spec.** List the screens and components its scenarios imply.
   Confirm the list with the user before designing — components are the
   review unit and later the build-chunk unit, so the split matters. Never
   assume anything the spec doesn't state (audience, tone, platform,
   brand constraints) — ask via AskUserQuestion before deriving tokens
   from it.

2. **Load the craft** — a chain; apply whichever are installed, in order:
   1. `frontend-design` (Anthropic official) — principles: derive tokens
      from product context, avoid the default AI looks.
   2. `design-taste-frontend` (taste-skill) — mechanical layer: hard bans,
      variance/motion/density dials, pre-flight checklist. Its
      landing-page-specific rules (hero/CTA/marquee) don't apply to
      component previews — skip those, keep the bans and the checklist.
   3. Neither installed → read
      `${CLAUDE_SKILL_DIR}/references/anti-slop.md` and apply it.
   If the project uses shadcn/ui (`components.json` present) and the shadcn
   skill is installed, follow it for component and theming conventions.
   Either way, before writing any component: write down the design tokens
   (type scale, colors, spacing, radius) derived from this product's actual
   context — never from habit.

3. **Build the previews** under `docs/design/{name}/`:
   - One self-contained HTML file per component or screen
     (`components/{component}.html`), real content from the spec's concrete
     examples — never lorem ipsum, never `[placeholder]`.
   - Show variants and states in one preview: default, hover/focus, empty,
     error, loading — the states the acceptance criteria mention.
   - First line of each preview file:
     `<!-- @dsCard group="{Group}" -->` so Claude Design can index it.
   - A `tokens.html` preview documenting the design tokens.

4. **The slop check, before showing the user.** Ask of the whole set:
   would a generically-prompted AI have produced this same design? If yes,
   it's default-cluster output — revise the tokens and the layout until the
   design is derived from *this* product's content and audience. Also check:
   consistent tokens across every component, no dead decoration, works in
   light and dark.

5. **Sync for review.** If the DesignSync tool is available (search tools
   for `DesignSync`): `list_projects` → pick or `create_project` for this
   product → `finalize_plan` with the preview paths → `write_files`. Tell
   the user to review in claude.ai/design. If the tool isn't available in
   this session, fall back to `file://` links to the local previews (they
   are self-contained). Either way this is a review gate: STOP for approval.

6. **Record and hand off.** Add a `## Design` section to the spec: the
   component list, the tokens, and where the previews live; regenerate the
   spec's HTML. The approved component list is the natural **Chunks** split
   for /refine — say so in the handoff. End with the review link(s).

## Iteration

Design review is loops, not a gate passed once. When the user wants changes,
edit the component files, re-sync only what changed (DesignSync is
incremental — never wholesale replace), and stop again.

If the `design-review` / `design-loop` skills (jezweb) are installed, run
their rendered-output audit (layout, type, contrast, hierarchy, states,
responsive) on the previews before each user review — catch what the
generation pass can't see about its own output.

Capture taste as lessons (learn skill): when the user's feedback states a
preference that will recur ("too corporate", "denser tables here", "never
cards for lists"), record it in `docs/learnings/` so the next design starts
from their taste, not the model's.
