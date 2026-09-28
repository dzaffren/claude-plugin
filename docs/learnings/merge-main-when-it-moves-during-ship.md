# Merge main in when it moves during /ship

**Learned:** 2026-09-28 · **From:** pr-attribution ship (PR #53)

Parallel sessions merged three PRs into `main` while #53 waited, each
appending to `OVERVIEW.md`, `CHANGELOG.md`, `DECISIONS.md` and the learnings
index. The first catch-up was a rebase, and pushing it needed a force push.
`block-dangerous.sh` blocks that whatever the user says, so the user had to run
it by hand. The next two catch-ups merged `origin/main` into the branch
instead: a plain push, no hook, no hand-off. A merge commit whose subject
follows the format (`chore: merge main into feat/{slice}`) passes the naming
gate.

## The rule

When `main` has moved under an open PR, merge it into the branch with a
conforming subject rather than rebasing. Resolve append-only conflicts by
keeping both sides, `main`'s first, so D-numbers and rows stay in order. Check
`mergeable` again right before merging, because main can move twice in an hour.
