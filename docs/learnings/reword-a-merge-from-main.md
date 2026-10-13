# Reword a merge from main before the ship gate reads it

**Learned:** 2026-10-13 · **From:** /build of pr-edit-attribution

pr-edit-attribution's branch was cut before fail-closed-parse merged. Both add
an entry at the end of `DECISIONS.md`, so the branch took `main` first, with
a merge, not a rebase, because a rebase rewrites history. git's default
subject, "Merge branch 'main' into ...", fails the ship gate's naming check,
which reads every commit ahead of the base, merges included.

## The rule

When a slice branch takes `main` with a merge, give the merge commit a
`chore(git): merge main into {branch}` subject while it is still local. Take
`main` before appending to an append-only file, so the new entry gets the next
free number.
