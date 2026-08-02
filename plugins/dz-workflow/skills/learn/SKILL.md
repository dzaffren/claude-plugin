---
name: learn
description: >
  Captures lessons about the current repo so future runs improve — and does
  it automatically. Use WITHOUT being asked whenever the user corrects an
  approach ("no, do X instead", "from now on", "always/never do X here"),
  a build hits a blocker worth remembering, a review keeps flagging the same
  thing, or a project-specific pattern is discovered. Also invoked by the
  build/quality/security/ship skills at the end of their runs, and explicitly
  via /learn ("remember that...", "capture this", "/learn audit",
  "/learn remove <slug>"). Lessons live in the target repo at
  docs/learnings/ and are auto-loaded into every session by this plugin's
  SessionStart hook.
---

# Learn

Record a lesson about the current repo the moment it appears, so no future
run repeats the mistake. Capture is automatic — don't ask permission for a
routine lesson; write it and mention it in one line. Only ask first when a
lesson would add a rule that changes behavior in a way the user might dispute.

## Where lessons live (in the target repo, never in this plugin)

```
docs/learnings/
├── INDEX.md                 # one line per lesson — auto-loaded every session
├── convention-<slug>.md     # team conventions (from review or corrections)
├── blocker-<slug>.md        # failure modes and what was tried
└── pattern-<slug>.md        # project-specific patterns worth reusing
```

Each lesson file:

```markdown
# {one-line rule}

**Type:** convention | blocker | pattern · **Captured:** {YYYY-MM-DD}

**Why:** {what happened that taught this — one or two sentences}

**How to apply:** {what to do differently next time}
```

`INDEX.md` holds one line per lesson:
`- [{rule}](convention-<slug>.md)` — keep it scannable; never put lesson
bodies in it.

## Modes

- **capture** (default) — before writing, scan `INDEX.md` for an existing
  lesson that covers it; update that file instead of duplicating. Add the
  INDEX line. If the repo tracks `docs/`, include the lesson in the current
  commit chunk.
- **update** — refine an existing lesson in place.
- **audit** (`/learn audit`) — list all lessons with dates. No writes.
- **remove** (`/learn remove <slug>`) — delete the file and its INDEX line.

## What makes a lesson worth capturing

- The user pushed back or corrected an approach — these are gold; capture
  the rule they implied, not the incident.
- A blocker cost real time and the cause wasn't in any doc.
- A reviewer (human or /quality, /security) flagged something that will
  recur.
- A repo-specific pattern was discovered that grep wouldn't reveal.

Not worth capturing: anything the repo already records (CLAUDE.md, README,
git history), one-off facts about this session, or user preferences (those
belong to personal memory, not the repo).

## Recall is automatic

This plugin's SessionStart hook prints `docs/learnings/INDEX.md` into
context at the start of every session in the repo. Apply the lessons without
being told; open a lesson file only when its one-line rule needs the detail.
