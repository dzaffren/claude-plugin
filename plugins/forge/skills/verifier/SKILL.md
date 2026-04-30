---
name: verifier
description: >
  Runs stack-aware verification checks (format, lint, type check, tests) on
  changed files. Use this skill whenever you've finished writing or editing code
  and need to confirm it's clean before marking a task done — after implementing
  a feature, fixing a bug, completing a sub-task, or any time you're about to say
  "done" or commit. If you're wrapping up and haven't called the verifier yet, call
  it now. Auto-detects the project stack (Node/Jest, Node/Vitest, Python,
  Java/Gradle, Java/Maven).
---

# Verifier

Run this before marking any task complete. It checks your changed files against
the project's full quality bar: format, lint, type safety, and tests.

## Run it

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/verify.sh
```

The script detects your stack automatically and runs the right checks. You don't
need to know the internals — just run it and read the result.

## Act on the result

**PASS** — Changes are clean. Proceed with your commit or mark the task done.

**FAIL** — The output tells you exactly what broke (`TYPE FAIL:`, `LINT FAIL:`,
`TEST FAIL:`, etc.). Fix those specific issues, then re-run. You get 2 attempts.

**FAIL after 2 attempts** — Stop. Don't keep guessing — a persistent failure usually
means something is structurally wrong (a missing dependency, a type constraint you
can't satisfy within scope, a test that needs a setup change). Write `BLOCKED.md`
at the repo root with:
- What you were implementing
- The exact error output from the last verify run
- What you tried and why it didn't work

Then stop and wait for a human.

## Why call this yourself if hooks run it automatically?

The Stop hook runs verify automatically, but it triggers *after* the agent loop ends.
Calling verify yourself during the task lets you catch and fix issues in the same
session — rather than burning another round on a fixable problem. Think of it as
your own pre-flight check before declaring done.
