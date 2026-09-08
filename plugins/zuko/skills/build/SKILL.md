---
name: build
description: >
  Implements an approved spec, test-first, scenario by scenario, on a branch.
  Splits into parallel chunks in isolated worktrees when the plan says so, and
  ends with the slice's end-to-end test green. Use when the user says "build
  it", "implement this", "write the code", or names an approved spec.
disable-model-invocation: true
allowed-tools: Write Edit Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git branch *) Bash(git checkout *) Bash(git switch *) Bash(git add *) Bash(git commit *) Bash(git stash *) Bash(git merge *) Bash(git worktree *) Bash(git fetch *) Bash(npm test *) Bash(npm run *) Bash(npx *) Bash(pnpm *) Bash(yarn *) Bash(pytest *) Bash(python -m *) Bash(uv run *) Bash(go test *) Bash(cargo test *) Bash(make *) Bash(bash *)
---

# Build

Turn an approved spec into working code with tests that prove it. Nothing
starts until the ledger is clear.

Read `${CLAUDE_PLUGIN_ROOT}/references/voice.md` and
`${CLAUDE_PLUGIN_ROOT}/references/slicing.md`.

## Gate — before anything

Run the gate **with the spec's path as its argument**:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-open-items.sh" docs/specs/{slice}.md
```

The path is not optional. Called with no argument the script runs in Stop-hook
mode, which only inspects specs already marked `Built` or `Shipped` — it would
sail straight past the `Refined` spec you are about to build. Exit 1 means the
build does not start.

Print the open rows, then work through them with the user one at a time. Each
becomes:

- `Resolved` — with the answer written into the row and the spec updated to
  match, or
- `Accepted risk` — with a stated reason and today's date.

An `unproven` row that a spike would settle → offer `/poc` instead of
guessing. Only when every row is closed does the build begin.

Also confirm: spec Status is `Refined`, the acceptance criteria have not
changed since approval, and the plan's commands actually exist in this repo.

## Steps

### 1. Branch

`feat/{slice}` off the current default branch, or the repo's own convention
if `CLAUDE.md` states one. Never build on `main` or `master`.

### 2. Split

Read the plan's **Chunks** table.

- `Single chunk` → build it here, in order.
- Multiple chunks → one `chunk-builder` agent per chunk, each with
  `isolation: worktree` so they cannot collide. Give each agent only its own
  scenarios, its own files, and the spec's relevant sections.

Rules that make parallel safe:

- Files are disjoint. One chunk owns every shared file — types, barrel
  exports, lockfiles, migration ordering. Other chunks read but never write
  them.
- Migrations are never parallel. One chunk owns the schema.
- After all chunks return, **integrate serially**: merge the worktrees, run
  the full suite, resolve conflicts yourself. Do not hand integration to an
  agent.

### 3. Build test-first, scenario by scenario

For each acceptance scenario, in order:

1. Write the test. Run it. **Watch it fail** for the right reason — a test
   that passes before the code exists is testing nothing.
2. Write the smallest code that makes it pass.
3. Run the test. Then run the suite.
4. Clean up what you just wrote before moving on. No dead code, no commented
   scaffolding, no leftover debug output.

Reuse what exists. The plan named the helpers — use those. A new parallel
implementation of something the repo already does is a defect.

Stay in scope. Touching a file the plan did not name means either the plan was
wrong (say so, add a ledger row) or you are drifting (stop).

### 4. Schema changes

Expand → backfill → switch, exactly as the plan says. The contract step is a
later slice.

The migration must run **forward and backward** in tests before this stage
ends. A migration you have not reversed is not finished.

### 5. The end-to-end test

The slice is not built until one e2e test walks the whole thing — the real
path, through every layer, following the acceptance criteria.

By project type:

| | The e2e test |
|---|---|
| Web UI | A browser test driving the real screens. Use `webapp-testing` when installed. |
| API / service | Real requests against a running server, real database. |
| CLI / library | Invoke the built binary, or import the built package. |
| Data / LLM app | A record through the whole pipeline with fixture data. Evals where output is generated. |

No harness in the repo → build it, as the plan said it would.

### 6. The flag

Unless the light path applies, the slice ships behind the flag the plan named,
default off. Wire it so that flipping it off fully removes the new behaviour —
a flag that leaves half the change live is not a rollback.

### 7. Report

Print: chunks and their results, tests added and passing, the e2e result, the
flag name, the branch, and anything you did that the plan did not anticipate.

Set spec Status to `Built`.

Capture lessons silently to `docs/learnings/` — corrections the user made,
things the plan got wrong, patterns worth remembering. Do not narrate this.

Say `/review` is next. Do not review your own work here.

## When the spec turns out wrong

You will sometimes discover mid-build that a scenario is impossible, a
constraint is different, or the whole slice is shaped wrong. Do not improvise
around it.

Stop. Add a ledger row saying what you found. Report to the user with a
proposal, and route back to `/spec` — which bumps the version and records what
was learned. Building something the spec does not describe is worse than
stopping.
