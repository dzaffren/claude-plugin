---
name: branch-new-work-from-integration-base
description: Start a new feature/fix branch from the integration base (main), not from whatever branch is currently checked out — otherwise it inherits the other branch's commits
type: blocker
captured: 2026-06-21
source: /build + /ship — Story 1 build-loop session (multi-PR)
scope: plugin-general
---

In a session with multiple branches/PRs in flight, `git checkout -b <new>`
branches from the **current** branch, not from `main`. If you are sitting on
another feature/fix branch, the new branch silently inherits that branch's
commits, and its PR then includes unrelated changes.

**Why:** This session, the Story 1 branch was created while still on the open
`fix/ship-step3e-bump-exit-code` (#13) branch, so it carried #13's commit — the
Story 1 PR would have shipped #13's Step 3e change as well.

**How to apply:** Before `git checkout -b` for independent work, put yourself on
the integration base first — `git checkout main && git pull --ff-only` — or
otherwise confirm the current branch is the base you intend. In multi-PR
sessions, make this an explicit step, not an assumption.

**What was tried:** Caught after committing; fixed non-destructively with
`git rebase --onto main <inherited-commit> <new-branch>`, which replayed only the
new branch's own commits onto `main` and dropped the inherited one. Verify with
`git diff --name-only main...HEAD` — it should list only your feature's files.
