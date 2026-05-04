---
name: learn-conflates-plugin-and-project-scope
description: /forge:learn captures both plugin-general and project-specific facts into the same `docs/learnings/` directory with no scope distinction
type: skill-quality
scope: plugin-general
captured: 2026-05-04
source: /learn — architectural observation raised by user after README pattern capture
skill: learn
---

`/forge:learn` today writes every learning to the target repo's
`docs/learnings/` directory with no distinction between two very different
kinds of facts:

1. **Plugin-general** — facts about how the forge plugin itself behaves
   (bugs, design choices, quirks). Example: "`bump-semver.sh` does not
   recognize Claude-plugin manifests." These facts help any user who
   installs the plugin.
2. **Project-specific** — conventions, deferred work, and architecture
   decisions for the specific project being built with the plugin.
   Example: "Our README should carry a single `**Current version:**`
   line." These facts are meaningless to other users.

The skill treats both identically. When the forge plugin is developed in
this repo, both types accumulate in the same `docs/learnings/` directory,
and a reader cannot tell at a glance which is which. When another user
installs forge in their own project, none of our accumulated
plugin-general knowledge travels with the plugin — they discover it fresh.

**Why:** Plugin-general learnings are team knowledge for every user of the
plugin; they should ship with the plugin code itself (e.g.
`plugins/forge/docs/known-issues.md` or
`plugins/forge/references/gotchas.md`). Project-specific learnings are
private team decisions for one repo; they stay in that repo's
`docs/learnings/`. Mixing the two loses information at the plugin
boundary and makes per-project learnings directories noisy for teams that
just wanted to track their own conventions.

**How to apply:** Three paths, in priority order. The user should pick
one; do not action without explicit permission.

1. **Quick mitigation (cheap, already done for PR #8):**
   - Add a `scope: plugin-general | project-specific` field to the
     frontmatter of every new learning starting now.
   - Lazy-migrate existing entries: next time a plugin-general learning is
     updated, move it to `plugins/forge/docs/known-issues.md` at that
     point. Do not big-bang the existing 9 entries.
   - Update the `/forge:learn` skill to prompt for scope during capture
     (one extra multi-choice question: "Is this about how forge behaves,
     or about your specific project?").

2. **Medium fix (bigger, more coherent):**
   - Create `plugins/forge/docs/known-issues.md` as the home for
     plugin-general facts.
   - Move the 8 plugin-general entries currently in `docs/learnings/`
     (everything except `pattern-readme-single-source-of-truth`) into it.
   - Update `/forge:learn` to route captures to the right file by scope,
     and to scan both locations when surfacing prior learnings at the
     start of `/forge:prd`, `/forge:prd-refine`, `/forge:build`.
   - Update `CLAUDE.md` to reflect the split.

3. **Full redesign:**
   - Full `/forge:prd` → `/forge:prd-refine` → `/forge:build` cycle on a
     new taxonomy that handles: per-user personal memory, per-project team
     learnings, per-plugin shipping knowledge, and cross-repo migration
     when plugins get updated. Out-of-scope for a quick fix.

**Skill:** learn

**What was tried (today, as a pragmatic first step):**

- Added a `scope: project-specific` field to
  `pattern-readme-single-source-of-truth.md`'s frontmatter so PR #8 lands
  correctly classified.
- Created this learning file with `scope: plugin-general` as the
  exemplar case — it's itself a fact about the plugin's `/forge:learn`
  skill, so it belongs with the plugin long-term.
- Did NOT migrate the 8 existing plugin-general entries — deferred, to
  avoid rewriting unrelated files in a docs-only PR.
- Did NOT update the `/forge:learn` skill prose to prompt for scope —
  that is the Option 2 change above and needs its own spec.

**Trigger phrases for resuming this work:**

- "fix the learn scope split"
- "move plugin-general learnings out of docs/learnings"
- "implement the learn-scope split"
- "route learnings by scope"
- "create `plugins/forge/docs/known-issues.md`"
