# Reverse a patch with `git apply -R`, never with checkout

**Learned:** 2026-05-04 · **From:** /ship code-review gate, forge PR #3 (ported 2026-09-11)

`git checkout -- <files>` resets to HEAD, discarding every uncommitted change
on those paths — the patch being rolled back *and* whatever the user was
mid-way through. It is data loss wearing a one-line rollback. The working tree
is dirty at exactly the moment a rollback runs; that is why the stage was
invoked.

Wrong: `git checkout -- <files>` to undo an auto-applied patch. Right: save the
patch before applying, then `git apply -R <patch>` in reverse order. Same for
`git restore` and `git reset --hard` on a path holding user work.
