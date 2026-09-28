# Parallel sessions in one checkout share one HEAD

**Learned:** 2026-09-28 · **From:** ledger-handoff build

Four sessions built slice 8's parts at once, all in the main checkout. After
ledger-handoff's gate commit, another session switched HEAD to
`fix/mermaid-placeholder`, then another to `feat/pr-attribution`. Three things
followed: ledger-handoff's uncommitted skill edits sat in pr-attribution's
working tree, where a `git add` there could commit them; all three sibling
branches were cut from `0a18359` and carry ledger-handoff's three commits; and
four suites running at once pushed timing tests past their `alarm`, failing
with exit 142. The edits were moved out with a saved patch, `git worktree
add` and `git apply -R` on the shared tree.

## The rule

A session that may run beside others builds in its own `git worktree`, never
the shared checkout. Check `git worktree list` and `pgrep -fl tests/run.sh`
before branching; if another session is live, `git worktree add` first. A
test that fails with 142 while other suites run is load, not a verdict —
rerun that file alone before believing it.
