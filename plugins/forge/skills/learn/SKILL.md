---
name: learn
description: >
  Captures lessons about the target repo so future runs improve over time.
  Use this skill whenever the user wants to record something Claude should
  remember for next time — a team convention discovered in review, a blocker
  and what was tried, a project-specific pattern, or a correction to how a
  skill behaved. Phrases that should trigger this skill include "remember
  that...", "for next time...", "capture this lesson", "record this
  learning", "from now on...", "always do X in this repo", "don't do Y
  here", and an explicit `/learn` command. Also invoked programmatically by
  the `learning-capturer` agent after `/build` or `/ship` completes and by
  the `/ship` skill when it parses pull-request comments. Stores the
  learning in the target repo at `docs/learnings/` so it travels with
  the code. Separate from Claude's personal auto-memory: this skill is for
  team/repo facts, not user preferences.
---

# Learn

Capture a lesson about the target repo so future workflow runs improve. Each
invocation does ONE of five things:

1. **capture** — record a new learning (default)
2. **update** — an existing learning needs refinement
3. **audit** — list all learnings with timestamps, no writes
4. **remove** — delete a learning and strip any rule it added to CLAUDE.md
5. **retro** — produce a "going right / going wrong" digest (read-only by default)

Pick the mode from context. If the user types `/learn audit`, `/learn retro`,
or `/learn remove <slug>`, do that. Otherwise assume capture and run the dedupe
check described below.

## Why this skill exists

Workflow runs (`/prd`, `/build`, `/ship`) currently start from scratch every
time — they re-read `CLAUDE.md` and the code but carry no memory of past
mistakes, reviewer corrections, or project-specific patterns. That means the
same team convention gets discovered and re-violated week after week.

This skill writes a learning into the **target repo** (not the plugin, not
Claude's personal memory), so it survives across sessions and is shared by
everyone working in that repo. Learnings are committed alongside code; they
are a team artifact.

## Where learnings live

In the target repo (the repo being worked on, not this plugin):

```
<target-repo>/
├── CLAUDE.md                           # active ruleset — keeps a `## Learnings`
│                                       # section synced with high-confidence rules
└── docs/
    └── learnings/
        ├── INDEX.md                    # one-line-per-learning pointer file
        ├── convention-<slug>.md        # team conventions from review
        ├── blocker-<slug>.md           # failure modes + what was tried
        ├── pattern-<slug>.md           # project-specific patterns
        ├── win-<slug>.md               # approaches that worked — repeat them
        └── skill-<slug>.md             # skill-quality corrections
```

Why `docs/learnings/` over `.claude/learnings/`: learnings are team artifacts,
not Claude state. Putting them in `docs/` keeps them visible to every team
member (wiki browsers, docs UIs), hand-editable without feeling like you're
poking Claude's internals, and portable if the team ever moves tooling.

Why hybrid storage:

- `CLAUDE.md` is already loaded every time Claude enters the repo. Keeping
  the highest-confidence rules there means workflow skills pick them up for
  free, with zero extra reads.
- `docs/learnings/` holds the full audit trail with richer `Why` / `How
to apply` text. Skills drill into it only when a CLAUDE.md rule references
  a specific learning, keeping the default context cost low.
- `INDEX.md` is the pointer file — one line per learning, always cheap to scan.

## Relationship to auto-memory

Claude's personal auto-memory (at `~/.claude/projects/.../memory/`) is
per-user and cross-repo. It holds user preferences like "always prefer LSP
over grep" — things that follow the human, not the code.

This skill writes per-repo team learnings. They follow the code.

If the user tells you a fact that could belong in either place, ask. Don't
silently pick. Personal preferences ("I always want to see diffs before
committing") go in auto-memory; team/repo conventions ("our backend uses
pino, not winston") go in repo learnings.

## Learning types

| Type          | File prefix   | When to use                                                                                                                                                             |
| ------------- | ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| convention    | `convention-` | Team decisions about how code should look. "We use CSS modules." "All API errors return a `code` field."                                                                |
| blocker       | `blocker-`    | A dead-end and what was tried, so future runs don't retread it. "Vitest workspace config requires `VITEST_POOL=1`."                                                     |
| pattern       | `pattern-`    | Project-specific patterns worth reusing. "Auth tests use the `seedUserWithRole` fixture."                                                                               |
| win           | `win-`        | An approach that worked well and should be repeated. The positive counterpart to `blocker`. "Using `msw` for network-layer mocks kept auth tests under 200 lines each." |
| skill-quality | `skill-`      | A skill produced wrong output and the user corrected it. "prd-refine keeps forgetting to include migrations."                                                           |

See [references/types.md](references/types.md) for worked examples of each.

## Capture mode (default)

### Step 1 — Understand the observation

The user may invoke you with an explicit argument (`/learn we don't use
inline styles`) or with a looser phrase ("hey, remember for next time we
always prefer Vitest"). Either way, extract:

- The **rule or fact** itself in one sentence.
- The **type** — convention, blocker, pattern, or skill-quality.
- The **why** — the reason behind it. If the user didn't give one, ask. A
  learning without a why is brittle: future runs can't judge edge cases.
- The **source** — was this from a review comment, a live correction, a
  blocker during a build, an PR comment? Record it.
- The **confidence signal** — did the user use absolute language ("always",
  "never", "from now on")? That matters for whether it ends up in
  `CLAUDE.md`.

If the rule is genuinely ambiguous, ask ONE clarifying question rather than
guessing. Do not ask more than one — this is a capture skill, not a grilling
session.

### Step 2 — Check for duplicates

Before writing, read `docs/learnings/INDEX.md` (create the directory
if it doesn't exist yet — this may be the first learning).

Scan the index for a learning whose description or slug overlaps with the
new observation. If you find a match:

- **Near-duplicate** (same rule, new wording) — run `update` mode on the
  existing file instead of creating a new one. Add the new source to its
  captured-from list and merge any new nuance into the `Why:` or `How to
apply:` body.
- **Contradiction** (new rule conflicts with existing) — stop and ask the
  user. Don't silently overwrite; a contradiction is a signal that either
  the old rule is stale or the new one is wrong, and only the user can
  resolve that.
- **No match** — proceed to Step 3.

### Step 3 — Write the learning file

Slugify the rule into a short kebab-case identifier (e.g. "we don't use
inline styles" → `no-inline-styles`). Write to
`docs/learnings/<type>-<slug>.md` with this exact frontmatter and body
structure:

```markdown
---
name: <slug>
description: <one-line description, used for the index entry>
type: <convention|blocker|pattern|win|skill-quality>
captured: <YYYY-MM-DD>
source: <how this was captured — /learn, /ship PR comment, /build session, etc.>
---

<The rule or fact, stated plainly.>

**Why:** <The reason behind it. Often a past incident, a reviewer's
feedback, or a constraint. This is what future-you uses to judge whether
the rule applies to an edge case.>

**How to apply:** <When and where the rule kicks in. Be specific about
scope — "in React components", "in backend handlers", "only for new
endpoints" — so the rule is actionable, not abstract.>
```

For `blocker`, `win`, and `skill-quality` types, add a third line:

- **blocker**: `**What was tried:** <summary of dead-ends>` so the next run
  skips the known-bad paths.
- **win**: `**What worked:** <the concrete approach that succeeded>` so the
  next run can replay it.
- **skill-quality**: `**Skill:** <skill-name>` so the fix can eventually be
  folded back into the skill itself.

Capture triggers for `win`: user language like "that worked well", "we should
always do this", "keep doing X", "good approach", or a post-build/ship signal
from `learning-capturer` showing a first-pass success without blockers.

### Step 4 — Update the index

Append to `docs/learnings/INDEX.md`:

```markdown
- [<title>](<type>-<slug>.md) — <one-line hook from the description>
```

Keep each entry under ~120 characters. If the index doesn't exist, create it
with this header:

```markdown
# Learnings Index

Per-repo learnings captured by the `/learn` skill. Each entry points to a
file in this directory. The active ruleset is synced into the repo's
`CLAUDE.md` under `## Learnings`.
```

### Step 5 — Decide whether to update CLAUDE.md

Append or update the `## Learnings` section in the repo's `CLAUDE.md` **only
if** the learning is high-confidence. High-confidence means ONE of:

- The user used absolute language: "always", "never", "from now on", "we
  don't", "we do".
- The user explicitly told you to update CLAUDE.md.
- A `learning-capturer` agent proposed it and the user approved with explicit
  "yes, make it a rule".

Otherwise the learning stays in `docs/learnings/` only. This matters
because `CLAUDE.md` is loaded on every session — it should hold rules the
team endorses, not speculative captures.

If CLAUDE.md doesn't yet have a `## Learnings` section, create it near the
end of the file (after any existing sections but before the last one, if
there's a clear "final" section like a changelog). Format each entry as:

```markdown
## Learnings

- **<title>** — <rule in one sentence>. See `docs/learnings/<type>-<slug>.md`.
```

If a related rule already exists in the section, update it in place rather
than appending a duplicate.

### Step 6 — Report

Respond with:

```
CAPTURED: <type>-<slug>
File: docs/learnings/<type>-<slug>.md
Index updated: yes
CLAUDE.md updated: <yes|no — reason if no>
```

If you updated an existing learning instead:

```
UPDATED: <type>-<slug>
File: docs/learnings/<type>-<slug>.md
Merged: <what was added — new source, expanded Why, etc.>
```

## Audit mode

When invoked as `/learn audit` (or when the user asks to list, review, or
audit learnings):

1. Read `docs/learnings/INDEX.md`.
2. For each entry, stat the file to get its `captured:` date.
3. Produce a table: slug | type | captured | description.
4. Do NOT write anything. This mode is read-only.

If the index is missing or empty, say so and stop.

## Retro mode

When invoked as `/learn retro [--days N]` (default `--days 14`) or when the
user asks for a "what's going right / going wrong" digest, an "activity
digest", a "retro", or a "recent learnings summary":

1. Read `docs/learnings/INDEX.md`. If missing or empty, say so and stop.
2. For each entry, stat the file to get its `captured:` date.
3. Filter to entries captured in the last `N` days.
4. Group by sentiment:
   - **Going right** — `win` entries + `pattern` entries that have a rule in
     `CLAUDE.md` (high-confidence).
   - **Going wrong** — `blocker` entries + `skill-quality` entries.
   - **Still being decided** — `convention` entries and uncommitted `pattern`
     entries (neutral).
5. Cross-reference with recent ships to tie learnings to merged work:
   ```bash
   git log --since="<N> days ago" --pretty='%h %s' origin/main 2>/dev/null
   ```
   If remote is unavailable, fall back to local `main`.
6. Emit a markdown digest to the conversation:

   ```markdown
   # Learn retro — last <N> days

   ## Going right (<count>)

   - **<title>** (<type>, captured <date>) — <description>. From <source>.

   ## Going wrong (<count>)

   - **<title>** (<type>, captured <date>) — <description>. From <source>.

   ## Still being decided (<count>)

   - **<title>** (<type>, captured <date>) — <description>. From <source>.

   ## Ships in window

   - <sha> <subject>
   - <sha> <subject>
   ```

7. If the user asks to save the digest, write it to
   `docs/learnings/retro-<YYYY-MM-DD>.md` with a one-line frontmatter
   `{generated: <date>, window_days: <N>}`. Do NOT add it to `INDEX.md`; it is
   a generated report, not a learning.

This mode is read-only by default. Never update `CLAUDE.md`, never mutate
existing learning files.

## Remove mode

When invoked as `/learn remove <slug>`:

1. Confirm the target exists in the index.
2. Delete the file at `docs/learnings/<type>-<slug>.md`.
3. Remove the pointer line from `INDEX.md`.
4. If the same learning has a rule in `CLAUDE.md`'s `## Learnings` section,
   remove that line too.
5. Report what was removed and from where.

Never remove without explicit user confirmation of the slug. Never guess the
slug from a description — ask the user to run `/learn audit` first if
unclear.

## Constraints

- **Do NOT capture silently.** Even when invoked by another agent
  (`learning-capturer`), the caller is responsible for user approval. This
  skill writes; it does not interrogate.
- **Do NOT write learnings into Claude's personal auto-memory.** That's a
  different system with a different purpose.
- **Do NOT brainstorm learnings the user didn't say.** Capture what was
  observed or stated, not what you think might be useful. Speculation
  bloats the file and erodes trust.
- **Do NOT treat this skill as a style guide.** Learnings are what the team
  has _actually decided_ about this repo. If the user asks for generic
  advice about good code, that's a different conversation.
- **Dedupe is mandatory on capture.** A learnings file that accumulates
  duplicates becomes noise — nobody reads the fifth copy of the same rule.
