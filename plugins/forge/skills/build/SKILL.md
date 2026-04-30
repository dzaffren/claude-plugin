---
name: build
description: >
  Executes an approved feature spec end-to-end: loads context, decomposes tasks,
  runs feature-builder subagents, verifies, and opens a PR. Use this skill
  whenever the user runs /build, says "build the spec", "implement this spec",
  "execute the feature spec", or provides a spec name/path and wants it built.
  Also triggers when the user says "build <feature-name>", "run the build for X",
  or "implement X from the spec" — even if they don't say "spec" explicitly.
---

# Build

Execute an approved feature spec end-to-end across five phases.

**Spec argument:** `$ARGUMENTS` — a spec name or path.
Resolve it in this order:

1. `docs/specs/$ARGUMENTS/spec.md`
2. `specs/$ARGUMENTS/spec.md`
3. `$ARGUMENTS` directly

---

## Phase 1 — Context Loading

1. Read `CLAUDE.md` at the repo root. If it has a `## Learnings` section, those rules apply to everything you do this run — follow them the way you'd follow CLAUDE.md's other conventions. If a rule points at a specific file in `docs/learnings/`, read that file when the work you're about to do touches the area the rule covers (e.g. a `convention-` file on CSS modules matters if this spec touches React components).
2. Read the spec file.
3. **Extract the ticket ID** — look for `**Ticket:** PROJ-123` near the top of the spec. Save it as `{ticket}`. If absent or `TBD`, set `{ticket}` to empty.
4. **Extract the spec type** — look for the `**Type:**` line near the top of the spec. Save it as `{spec-type}`. If absent, set `{spec-type}` to empty (it will default to `feature` in Phase 2).
5. If the spec has multiple **repo scopes** (e.g. "Backend Scope", "Frontend Scope"), identify which scope matches this repo and **load only that scope**. Ignore all others.
6. From the spec's **Architecture Decision** section, read every listed file.
7. Read the exemplar files named in the spec.
8. Find relevant existing tests for the modules being changed.

**Hard limit: 15 files total.** If you'd exceed that, drop the least relevant files — architecture decision files and exemplars take priority over test files.

---

## Phase 2 — Task Decomposition

Read the **Implementation Plan** from the spec.

- Tasks labelled `INDEPENDENT` → launch as parallel `feature-builder` subagents (all in one turn).
- Tasks labelled `SEQUENTIAL` → queue them and run in order, each waiting for the previous to finish.

If tasks have no label, use judgment: tasks that touch different modules are usually safe to parallelize; tasks that share state or build on each other's output must be sequential.

**Before proceeding to Phase 3**, ask the user: "Which branch should I use as the base? All sub-task worktrees and the final build branch will be checked out from it." Wait for their answer and save it.

Read `../ship/references/branch-conventions.md` to determine the correct branch name format.

Map `{spec-type}` (from Phase 1) to a branch prefix:

| Spec type contains…                                              | Prefix      |
| ---------------------------------------------------------------- | ----------- |
| `Bug` (e.g. "Bug Report", "Bug Fix")                             | `fix/`      |
| `Refactor`                                                       | `refactor/` |
| `Infrastructure`, `Dependency Upgrade`, `Migration`, `Tech Debt` | `chore/`    |
| `Performance`, `Security`                                        | `fix/`      |
| Anything else, or empty                                          | `feature/`  |

If the spec type is `Technical — [subtype]`, match on the subtype. When in doubt, default to `feature/`. Save the chosen prefix as `{branch-prefix}`.

Determine the branch name following those conventions:

- If `{ticket}` is set: `{branch-prefix}{ticket}-{spec-name}` (e.g. `fix/PROJ-123-cart-total-rounding`)
- Otherwise: `{branch-prefix}{spec-name}`

Save this as `{build-branch}`. Then run these commands **in order**:

```
git checkout {base-branch}
git checkout -b {build-branch}
```

You must be on `{build-branch}` before launching any sub-tasks. The build branch must exist before Phase 3 begins — creating it later is not allowed. The base branch is now frozen: **no commits or merges should ever target it during this build**.

---

## Phase 3 — Execution

For each sub-task, invoke the `feature-builder` agent with exactly:

- The sub-task description
- Only the files relevant to that sub-task (subset of what you loaded)
- The acceptance criteria for that sub-task
- The exemplar file path
- Any E2E test assignments for this sub-task (from the spec's Verification >
  E2E Tests table — include the scenario name, test file path, and the
  corresponding Key Scenario's Given/When/Then). If none assigned, omit this.

Do not pass the whole spec or all loaded files to every subagent — give each one only what it needs.

Each `feature-builder` follows TDD discipline: RED→GREEN per acceptance criterion before moving to the next. Tests are written before implementation, not after.

**Merging rules during execution:**

- **SEQUENTIAL task completes** → immediately merge its worktree branch into `{build-branch}` before launching the next task or batch:

  ```
  git checkout {build-branch}
  git merge --no-ff {worktree-branch} -m "Merge sub-task: {task-name}"
  ```

  Dependent tasks launched afterward will branch from `{build-branch}` and will have this task's changes.

- **INDEPENDENT task completes** → collect the branch name only. Do not merge. All independent task branches are merged together in Phase 3.5.

- **On merge conflict during a sequential merge**: abort immediately, write `BLOCKED.md`, and stop. Do not launch any further tasks.

---

## Phase 3.5 — Branch Collection & Merge

After all `feature-builder` subagents have completed:

> **HARD RULE: Never merge or commit anything to the base branch.** The base branch is read-only throughout this entire process. All merges happen on `{build-branch}` only.

1. **Confirm you are on the build branch** — `{build-branch}` was created at the end of Phase 2. Run `git branch --show-current` and confirm it returns `{build-branch}`. If it does not, something has gone wrong — stop and report the discrepancy rather than proceeding.
2. **Collect INDEPENDENT worktree branches** — SEQUENTIAL task branches were already merged into `{build-branch}` during Phase 3. Only collect branches from INDEPENDENT tasks here. Subagents that made no changes produce no branch; skip them.
3. **Merge INDEPENDENT branches** — all merges target `{build-branch}`, never the base branch. Merge in the order they completed:
   - For each branch: `git merge --no-ff {branch} -m "Merge sub-task: {task-name}"`
4. **On merge conflict**: abort the merge immediately. Write `BLOCKED.md` at the repo root listing:
   - Which task's branch caused the conflict
   - Which files conflicted
   - Steps to resolve manually
     Do NOT attempt to resolve conflicts automatically. Stop here.
5. **On success**: confirm with `git branch --show-current` that you are on `{build-branch}`, then proceed to Phase 4.

---

## Phase 4 — Verification

After Phase 3.5 completes:

1. Run the `verifier` skill.
2. Check every acceptance criterion from the spec.
3. If any criterion is unmet: spawn one targeted fix agent for that criterion (max 1 retry per criterion).
4. Invoke the `e2e` skill to run the full E2E suite.
   - `NO_E2E` → skip, continue to Phase 5.
   - `PASS` → continue to Phase 5.
   - `FAIL` → spawn one targeted fix agent per failing test (max 1 retry each), then re-run the `e2e` skill.
   - `ERROR` → write `BLOCKED.md` and stop (do not attempt to fix infra/config issues).
5. Cross-check the spec's E2E Tests table (in the Verification section): confirm every mapped scenario has a corresponding test file that was created and passed. Report any gaps.
6. If any criterion or E2E test is still failing after retries: write `BLOCKED.md` at the repo root listing:
   - Which criteria or E2E tests failed
   - What was attempted
   - What blocked progress

---

## Phase 5 — Ship

Invoke the `ship` skill to handle commit, push, and PR creation:

- Pass `{ticket}` as the argument if set (e.g. `PROJ-123`), otherwise no argument
- Ship detects the current git state and picks up from the right step — it will push the branch and create the PR following project conventions
- If any acceptance criteria were unmet in Phase 4, tell ship to create the PR as a draft

---

## Phase 6 — Capture Learnings

After ship completes, invoke the `learning-capturer` agent with the session
signals: the spec path, the final diff (`git diff {base-branch}...HEAD`),
the verifier output from Phase 4, any `BLOCKED.md` written, and any
in-session user corrections worth flagging.

The agent proposes candidates (or reports "no candidates" — the common
outcome). If it proposes any, relay them to the user for approval. For each
approved candidate, let the agent hand off to the `learn` skill so the
write, dedupe, and optional CLAUDE.md sync happen through the single
canonical path.

Do not capture silently. Do not prompt for approval if the agent returns
no candidates — silent is fine.
