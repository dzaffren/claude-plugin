# Build Skill: Worktree Branch Handoff

**Type:** Enhancement
**Auth:** N/A (internal plugin skill)

The `build` skill spawns `feature-builder` subagents with `isolation: worktree`, each producing changes on an auto-named temporary branch. Currently, Phase 5 creates `feature/{spec-name}` without explicitly collecting and merging those worktree branches first — leaving the handoff implicit and unreliable. This spec adds an explicit Phase 3.5 that collects worktree branches and merges them into the final branch before verification and MR creation.

## Problem

**Current behavior:** After all `feature-builder` subagents complete (Phase 3), the build skill jumps straight to running the verifier (Phase 4) and then creating a PR on `feature/{spec-name}` (Phase 5). There is no instruction for how to collect the changes from each subagent's isolated worktree branch, create the final branch, or merge the worktree branches into it.

**Desired behavior:** After Phase 3, the build skill explicitly:

1. Records the current branch as the base (via `git rev-parse --abbrev-ref HEAD`)
2. Creates `feature/{spec-name}` from that base and checks it out
3. Merges each worktree branch into `feature/{spec-name}` in execution order
4. Proceeds to Phase 4 (verification) — which simply runs on the current branch, already `feature/{spec-name}`
5. Phase 5 pushes the existing branch and opens an MR — no branch creation needed

## Scope

- **In scope:** Adding a Phase 3.5 section to `SKILL.md`; removing the redundant branch creation note from Phase 5; renaming all "PR" references to "MR"; removing the target branch row from the Phase 5 table (the MR target is the base branch recorded in Phase 3.5)
- **Out of scope:** Changes to `feature-builder.md`; changes to how worktrees are created; changes to the verifier logic or MR body format

## Requirements

- [ ] The build skill must capture the branch name from each completed `feature-builder` subagent result
- [ ] The build skill must record the current branch as base before creating `feature/{spec-name}`
- [ ] Worktree branches must be merged in execution order: SEQUENTIAL tasks in their defined order, INDEPENDENT tasks in the order they completed
- [ ] If a merge conflict is detected, the build skill must write `BLOCKED.md` listing which tasks conflicted and stop — do not attempt auto-resolution
- [ ] Phase 4 (verifier) runs on the current branch with no branch-switching — it is already `feature/{spec-name}` after Phase 3.5
- [ ] Phase 5 pushes the existing `feature/{spec-name}` branch and opens an MR targeting the recorded base branch — no `git checkout -b` in Phase 5
- [ ] All "PR" and "pull request" references in `SKILL.md` must be replaced with "MR" and "merge request"

## Solution

**Changes:**

- `plugins/did-workflow/skills/build/SKILL.md` — insert Phase 3.5 between Phase 3 and Phase 4; simplify Phase 4 opening (no branch qualifier needed); update Phase 5 table to remove branch creation, update target to base branch recorded in 3.5, rename PR → MR throughout

**New dependencies:** none

**Dependencies & integration:** The `Agent` tool with `isolation: worktree` returns a worktree branch name in its result when the subagent commits changes. Phase 3.5 relies on capturing that return value.

## Phase 3.5 — Branch Merge (new section content)

Insert the following section between Phase 3 and Phase 4 in `SKILL.md`:

```markdown
## Phase 3.5 — Branch Collection & Merge

After all `feature-builder` subagents have completed:

1. **Record the base branch** — run `git rev-parse --abbrev-ref HEAD` and save the result (e.g. `dev`, `main`).
2. **Create and checkout the feature branch** — run `git checkout -b feature/{spec-name}`.
3. **Collect worktree branches** — from each completed subagent result, extract the branch name returned by the worktree isolation. Subagents that made no changes produce no branch; skip them.
4. **Merge in execution order**:
   - SEQUENTIAL tasks: merge in their defined order.
   - INDEPENDENT tasks: merge in the order they completed.
   - For each branch: `git merge --no-ff {branch} -m "Merge sub-task: {task-name}"`
5. **On merge conflict**: abort the merge immediately. Write `BLOCKED.md` at the repo root listing:
   - Which task's branch caused the conflict
   - Which files conflicted
   - Steps to resolve manually
     Do NOT attempt to resolve conflicts automatically. Stop here.
6. **On success**: the working tree is now on `feature/{spec-name}` with all sub-task changes. Proceed to Phase 4.
```

## Phase 5 — MR (updated table)

The Phase 5 table in `SKILL.md` should become:

| Field      | Value                                                 |
| ---------- | ----------------------------------------------------- |
| **Title**  | Descriptive summary of what was built                 |
| **Branch** | `feature/{spec-name}` (already exists from Phase 3.5) |
| **Target** | The base branch recorded in Phase 3.5                 |
| **Draft**  | Yes, if any acceptance criteria were not met          |

## Test Cases

**Test 1: Two INDEPENDENT tasks, no conflicts**

- Setup: spec with two INDEPENDENT tasks touching different files (`src/auth.ts` and `src/billing.ts`)
- Action: both feature-builder subagents complete; Phase 3.5 runs
- Expected: `feature/add-payments` branch created; both worktree branches merged in; `src/auth.ts` and `src/billing.ts` both present with changes; verifier runs on `feature/add-payments` without any branch switch

**Test 2: Two SEQUENTIAL tasks building on each other**

- Setup: spec with SEQUENTIAL tasks where task-2 adds a method to a class created by task-1
- Action: task-1 completes first, task-2 completes second; Phase 3.5 runs
- Expected: task-1 branch merged first, task-2 branch merged second; final branch contains both changes cleanly; no branch switch needed before Phase 4

**Test 3: Merge conflict detected**

- Setup: two INDEPENDENT tasks that both modify the same line in `src/config.ts`
- Action: both subagents commit their changes; Phase 3.5 attempts merge of second branch
- Expected: merge is aborted; `BLOCKED.md` written with conflicting task name and file path; build stops before Phase 4

## Acceptance Criteria

- [ ] `SKILL.md` contains a Phase 3.5 section between Phase 3 and Phase 4
- [ ] Phase 3.5 records the base branch with `git rev-parse --abbrev-ref HEAD` before creating the feature branch
- [ ] Phase 3.5 specifies merge order: SEQUENTIAL tasks in defined order, INDEPENDENT tasks in completion order
- [ ] Phase 3.5 specifies `--no-ff` merge with a descriptive commit message per task
- [ ] Phase 3.5 specifies writing `BLOCKED.md` and stopping on merge conflict — no auto-resolution
- [ ] Phase 4 has no branch-switching instruction — verifier runs on current branch
- [ ] Phase 5 table notes branch already exists; target is the base branch from Phase 3.5
- [ ] All "PR" / "pull request" occurrences in `SKILL.md` replaced with "MR" / "merge request"
- [ ] All existing SKILL.md phase content is otherwise unchanged

## Verification

### Manual (human in the loop)

- [ ] Read the updated `SKILL.md` end-to-end and confirm phase numbering and flow is coherent
- [ ] Confirm no existing phase content was accidentally altered
- [ ] Confirm zero remaining "PR" or "pull request" occurrences in `SKILL.md`

## Open Questions

- [x] ~~Should conflicts be auto-resolved?~~ — **Resolved:** No. Conflicts indicate tasks touched the same code unexpectedly, which is a spec design issue. Surface it to the human via `BLOCKED.md`.
- [x] ~~Should INDEPENDENT tasks be merged in alphabetical order or completion order?~~ — **Resolved:** Completion order — it's deterministic based on what actually ran and avoids an arbitrary sort.
- [x] ~~Should the base branch be hardcoded to `dev`?~~ — **Resolved:** No. Record it dynamically at the start of Phase 3.5 so the skill works regardless of default branch name. Phase 5 MR target uses the same recorded value.
