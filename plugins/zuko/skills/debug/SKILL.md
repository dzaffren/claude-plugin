---
name: debug
description: >
  Reproduces a bug, finds the actual root cause, then fixes it if the fix is
  small and safe, or routes it to /spec when it is a design problem. Use when
  the user reports something broken, a test fails, behaviour is wrong, or they
  say "why is this happening", "debug this", "it crashes".
disable-model-invocation: false
---

# Debug

Find the real cause. Never patch a symptom.

Read `${CLAUDE_PLUGIN_ROOT}/references/voice.md`.

## Steps

### 1. Reproduce it first

Do not theorise before you have seen it fail. Get: exact steps, actual result,
expected result, environment, and when it started.

Cannot reproduce → say so and ask for what is missing. A fix for a bug you
have not seen is a guess.

Write a failing test that captures it, if the repo has tests. That test is how
you will know it is fixed, and it stops the bug coming back.

### 2. Trace the real path

Read the code along the actual execution path, not the path you assume. Follow
it with `file:line` references. Use `git log` and `git blame` on the relevant
lines — when did this change, and what else changed with it?

Narrow by bisecting behaviour, not by guessing: what is the last point where
the state is right, and the first where it is wrong?

### 3. Name the root cause

One sentence, at the level of the actual defect. Then draw the traced path —
symptom back to cause — as a diagram. That picture is usually the whole
explanation.

Test it: if you fix this, does the symptom have to disappear? If you can
imagine it still happening, you have not found the cause.

Common false bottoms: "the value was null" (why?), "the race condition" (what
two things race?), "it was a caching issue" (what cached what, and when?).

### 4. Decide the route

| The fix is | Do |
|---|---|
| Small, local, obviously right, inside one file or one function | Fix it here. Failing test first, then the fix, then the suite. |
| Touching several modules, changing an interface, or altering behaviour someone depends on | Do not fix it here. Write the diagnosis and route to `/spec` — it is a design change, and it needs a slice. |
| Revealing a wrong assumption in a live spec | Add a ledger row to that spec, then route. |

Unsure which → treat it as the second. A quiet architectural change under the
name of a bug fix is how systems rot.

### 5. Report

The root cause in one sentence, the traced path with the diagram, what you
changed or what you recommend, and whether a regression test now exists.

Capture the lesson to `docs/learnings/` when the cause is a pattern that will
recur — not for one-off typos.
