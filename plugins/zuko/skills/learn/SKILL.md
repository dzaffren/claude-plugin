---
name: learn
description: >
  The lesson store. Capture happens automatically inside the other stages;
  this skill is for auditing, consolidating, and removing lessons. Use for
  "/learn", "what have you learned", "clean up the learnings", "forget that".
disable-model-invocation: false
---

# Learn

Lessons live in the target repo's `docs/learnings/`, with `INDEX.md` as a
one-line-per-lesson summary that a SessionStart hook prints into every session.

Read `${CLAUDE_PLUGIN_ROOT}/references/voice.md`.

## Capture — automatic, not a command

The stages capture silently. Never announce it, never ask permission.

| When | What gets captured |
|---|---|
| The user corrects you | The correction, as a rule |
| The user says "from now on", "never do X here", "always Y" | Immediately, the moment it happens |
| `/review` finds the same class of problem a third time | The pattern |
| `/build` hits a blocker the plan missed | What to check next time |
| `/design` feedback states a recurring taste preference | The preference |

A lesson is one file, `docs/learnings/{slug}.md`:

```markdown
# {One-line rule, imperative}

**Learned:** {date} · **From:** {slice or stage}

{Two or three sentences: what happened, why the rule.}

{Concrete example — the wrong way and the right way.}
```

`INDEX.md` carries one line per lesson: the rule, nothing else. That file is
what gets loaded every session, so it stays short.

## What is worth keeping

**Yes:** project conventions the code does not state; a trap in this codebase;
a preference the user stated that will recur; a fact about the deployment or
environment that is not written down.

**No:** general programming advice; anything already in `CLAUDE.md`; a one-off;
a restatement of what the code plainly shows.

The test: would removing this line cause a mistake next time? No → do not
write it.

## `/learn audit`

List every lesson: rule, date, source, and whether anything referenced it
since. Flag lessons that contradict each other, and lessons about code that no
longer exists.

## `/learn consolidate`

Lessons rot. This is the prune.

1. **Merge duplicates.** Three lessons saying the same thing become one.
2. **Drop the stale.** The file it refers to is gone, the convention changed,
   the framework moved on.
3. **Promote the permanent.** A lesson that is really a project convention
   belongs in `CLAUDE.md`. Move it and say so.
4. **Resolve contradictions.** Two lessons disagree → ask the user which
   holds, delete the loser.
5. **Rebuild `INDEX.md`.** Short. If it is long enough to skim rather than
   read, it is too long.

Show the before and after counts, and every deletion. Never delete silently.

## `/learn remove {slug}`

Delete the file, rebuild the index, confirm.
