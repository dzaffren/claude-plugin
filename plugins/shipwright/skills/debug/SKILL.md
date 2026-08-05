---
name: debug
description: >
  Finds the root cause of a bug before any fix, then fixes it when the change
  is small and safe, or routes it to /refine when it's design-level. Use when a
  test fails, behaviour is wrong, or the user says "debug this", "why is X
  happening", "find the bug", "this is broken", "what's the root cause".
  Reactive and standalone — not a forward pipeline stage. Defers to
  systematic-debugging and test-driven-development when installed.
---

# Debug

Find why something is actually broken before touching a fix. A bug you can't
reproduce isn't understood, and a fix aimed at a symptom just moves the bug
somewhere else. Reactive and standalone — reach for it whenever behaviour is
wrong, wherever the work sits in the pipeline.

## Steps

1. **Reproduce it first.** Pin down the exact input, state, and command that
   makes it fail, then turn that into a **failing test** (defer to
   `test-driven-development` (obra/superpowers) when installed): red now, green
   when fixed, and it stays as the regression guard. Can't reproduce it → say
   so and gather what's missing (logs, steps, environment); never "fix" a bug
   you can't trigger.

2. **Isolate the root cause.** Defer to `systematic-debugging`
   (obra/superpowers) when installed — it drives the hunt. Not installed, hold
   its discipline yourself: read the real error and stack, form ONE hypothesis
   at a time, and binary-search the failure (bisect commits, halve the input,
   disable halves of the code) until you can point at the line that is wrong
   and say why. Confirm with evidence — a log line, a breakpoint, a passing
   sub-case — not a plausible story. The symptom is where it shows; the cause
   is usually elsewhere.

3. **Size the fix.** With the cause proven, decide:
   - **Small and safe** — a local change that reopens no design decision. Fix
     it here (step 4).
   - **Design-level** — touches a contract, schema, shared path, or how a
     feature is meant to work. Route it (step 5); do NOT patch it inline.

4. **Fix small and safe.** Make the change, keep the step-1 test (now green),
   and rerun the project's real test command — the whole suite, not just the
   one test. Report the ACTUAL output, never "should pass"
   (`verification-before-completion` when installed). Commit the fix and its
   regression test as their own chunk.

5. **Route design-level.** Write the root cause into the relevant spec — or a
   fresh `docs/specs/{name}.md` with just a Problem section if none exists:
   what breaks, the proven cause with its evidence, and a one-line sketch or
   small Mermaid of where it fails. Then hand to `/refine` for the fix plan →
   `/build`. Say plainly why it's too big to patch here.

6. **Capture the lesson** (learn skill), without being asked, when the bug is a
   class that will recur — a footgun in the code, an assumption the tests
   didn't cover, a convention that would have prevented it. Skip one-off typos.

Hand off: fixed here → `/quality` next. Routed → `/refine`.
