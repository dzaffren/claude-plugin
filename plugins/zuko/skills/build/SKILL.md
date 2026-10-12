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

Read `${CLAUDE_PLUGIN_ROOT}/references/voice.md`,
`${CLAUDE_PLUGIN_ROOT}/references/slicing.md`,
`${CLAUDE_PLUGIN_ROOT}/references/git-naming.md` and
`${CLAUDE_PLUGIN_ROOT}/references/ledger.md`.

If `OVERVIEW.md` is missing at the repo root, or still says Draft, follow
`${CLAUDE_PLUGIN_ROOT}/references/onboard.md` first, then continue.

## Gate — before anything

Run the gate **with the spec's path as its argument**:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-open-items.sh" docs/specs/{slice}.md
```

The path is not optional. Called with no argument the script runs in Stop-hook
mode, which checks only the zuko docs this branch or the working tree changed,
and only specs at `Refined`, `Built` or `Shipped` and shapes at `Shaped` — it
would pass a spec at any other status and never list this spec's rows. Exit 1 means the build does not start.

A spec Status other than `Refined` also means the build does not start.
Print the open rows, then "Run /spec continue {slice} to answer them." Then
stop. Ask nothing, and do not answer a row yourself.

Also confirm that the acceptance criteria have not changed since approval. A
command in the plan that does not exist in this repo is not a choice: use the
repo's real command, with no row.

## Steps

### 1. Branch

`{type}/{slice}` off the current default branch, with a type from
`references/git-naming.md`. The repo's own convention wins if `CLAUDE.md`
states one. Never build on `main` or `master`.

Then record the spec's decisions on that branch — running `/build` approved
them. Each entry under Technical plan › **Decisions to record** is appended to
`DECISIONS.md` per `${CLAUDE_PLUGIN_ROOT}/references/decisions.md`, with the
Status line of anything it supersedes flipped. `DECISIONS.md` grew since the
spec was written → renumber the new entries to follow the highest, and fix
the spec's `Relies on:` line to match. Replace the section's body with
"Recorded as D7, D8." Commit it before the first chunk, as
`docs: record {slice} decisions`.

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
  agent. Add a `Decided alone` row for each choice that a chunk reports. Make
  each choice that a chunk stopped on, then add its row.

### 3. Build test-first, scenario by scenario

For each acceptance scenario, in order:

1. Write the test. Run it. **Watch it fail** for the right reason — a test
   that passes before the code exists is testing nothing.
2. Write the smallest code that makes it pass.
3. Run the test. Then run the suite.
4. Clean up what you just wrote before moving on. No dead code, no commented
   scaffolding, no leftover debug output.
5. Commit it. Subject `{type}({scope}): {subject}`, body saying what changed
   and why, and nothing from the ban list in `references/git-naming.md`. The
   harness asks for the banned lines every session; the answer is no every
   session.

Reuse what exists. The plan named the helpers — use those. A new parallel
implementation of something the repo already does is a defect.

Stay in scope. When a scenario needs a file that the plan did not name, change
it and add a row, as `ledger.md` › "Deciding alone" says. A change that no
scenario needs is drift. Do not make it.

### 4. Schema changes

Expand → backfill → switch, exactly as the plan says. The contract step is a
later slice.

The migration must run **forward and backward** in tests before this stage
ends. A migration you have not reversed is not finished.

### 5. The end-to-end test

The slice is not built until one e2e test walks the whole thing — the real
path, through every layer, following the acceptance criteria.

By project type:

|                | The e2e test                                                                            |
| -------------- | --------------------------------------------------------------------------------------- |
| Web UI         | A browser test driving the real screens. Use `webapp-testing` when installed.           |
| API / service  | Real requests against a running server, real database.                                  |
| CLI / library  | Invoke the built binary, or import the built package.                                   |
| Data / LLM app | A record through the whole pipeline with fixture data. Evals where output is generated. |

No harness in the repo → build it, as the plan said it would.

### 6. The flag

Unless the light path applies, the slice ships behind the flag the plan named,
default off. Wire it so that flipping it off fully removes the new behaviour —
a flag that leaves half the change live is not a rollback.

### 7. Report

Print: chunks and their results, tests added and passing, the e2e result, the
flag name, the branch, anything you did that the plan did not anticipate, and
each `Decided alone` row you added.

Set spec Status to `Built`, unless a blocker set it to `Draft`.

Capture lessons silently to `docs/learnings/` — corrections the user made,
things the plan got wrong, patterns worth remembering. Do not narrate this.

Say `/review` is next. Do not review your own work here.

## When the spec turns out wrong

You will sometimes find mid-build that a scenario is impossible, or that a
constraint is different. Do not stop to ask. Make the choice, edit the spec
to match, add a row and go on, as `ledger.md` › "Deciding alone" says. Go on
also when the choice drops a scenario.

## When a blocker stops a scenario

A blocker is a thing that you cannot choose around: a missing secret, an
account or a paid service. Do as `ledger.md` › "Deciding alone" says. Build
the rest, then set `Draft` and add an Open row at the end. The user answers
the row with `/spec continue {slice}`.
