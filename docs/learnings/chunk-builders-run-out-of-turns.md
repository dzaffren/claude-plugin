# A chunk-builder runs out of turns before it commits

**Learned:** 2026-11-09 · **From:** needs-validation and coverage-ledger builds

In both builds, one chunk-builder hit its 60-turn limit. In needs-validation,
chunk B had three prompts, an e2e test and three fixtures. In coverage-ledger,
chunk A had a new module, its test file and seven fixtures, and it had not
made one commit. Each time the work sat uncommitted in the worktree, and the
agent had to be resumed to commit and report.

## The rule

Tell each chunk-builder to commit after each step, and to commit what passes
first when its turns run low. Give the largest chunk an order of work in the
brief. When an agent stops at its limit, check `git status` in its worktree
before you resume it, and tell it to commit first.
