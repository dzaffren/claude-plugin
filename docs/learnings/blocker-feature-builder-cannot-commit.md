---
name: feature-builder-cannot-commit
description: Feature-builder agents in isolated worktrees are denied `git add` / `git commit` by default; parent session must commit for them
type: blocker
captured: 2026-05-04
source: /build — ship-release-automation Sub-task 4 (PR #6)
---

When `/forge:build` launches a `feature-builder` agent with
`isolation: worktree`, the agent's `Bash` tool denies `git add` and
`git commit` commands. The agent can edit files fine, but cannot land a
commit — it returns with a message like "denied permission to run `git
add` / `git commit` … please approve or run manually".

**Why:** Worktree-isolated agents don't inherit the parent session's git
write authorization. This is a safety default — an agent editing code
shouldn't be able to alter repo history without explicit per-session
approval. Sub-task 4 of the ship-release-automation build hit this: the
SKILL.md edit completed successfully but the commit was denied.
Sub-tasks 1, 2, and 3 (also in worktrees) did NOT hit it in the same
run, suggesting the denial depends on the user's permission-prompt
response history within the session rather than being universal.

**How to apply:** When orchestrating `/forge:build`:

1. **Don't assume feature-builder commits work.** Check each agent's
   return summary for commit evidence (SHA, "commits made", or similar).
2. **If an agent reports the edit landed but was denied on commit:** run
   the commit yourself in the agent's worktree. Steps:
   - `cd /path/to/worktree` (worktree path is in the agent's return
     payload).
   - `git status --short` to confirm the uncommitted edit.
   - `git add <files> && git commit -m "<conventional-commit-subject>"`
     — use the exact commit message the agent suggested.
   - `cd /original/repo` — the merge step in Phase 3/3.5 picks up the
     newly-committed state automatically.
3. **For the first sub-task in a /build run,** be ready to approve
   `git add` and `git commit` explicitly if prompted — the parent
   session's approval sometimes fails to propagate to worktree-isolated
   agents on the first launch.

**What was tried:** Attempted to have the Sub-task 4 feature-builder
commit its own SKILL.md edit. The agent made the file change correctly
but returned before committing, noting permission denial. Resolved by
`cd` into the worktree path, running `git add` and `git commit -m` in
the parent session, then proceeding to the Phase 3.5 merge. Total loss:
one extra user authorization turn. The fix adds ~10 seconds of latency
but no work is lost.
