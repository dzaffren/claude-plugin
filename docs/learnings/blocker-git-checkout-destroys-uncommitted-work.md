---
name: git-checkout-destroys-uncommitted-work
description: Never use `git checkout -- <files>` to revert an auto-applied patch on a dirty working tree
type: blocker
captured: 2026-05-04
source: /ship — PR #3 code-review gate (self-caught)
---

Do **not** use `git checkout -- <files>` (or `git restore <files>`) to
undo an auto-applied patch when the working tree has other uncommitted
changes on the same files. Use `git apply -R <patch>` instead.

**Why:** `git checkout` resets files to their HEAD state, discarding
**all** uncommitted changes on those files — the patch you applied
AND any pre-existing diff the user was mid-working on. It's a
data-loss bug hiding inside a one-line "rollback". `git apply -R` reverses
exactly the patch that was applied and leaves everything else untouched.

**How to apply:** Whenever a skill, hook, or script applies a patch
programmatically and might need to roll back:

1. Save the patch to a known path before applying.
2. On rollback, run `git apply -R <patch>` for each applied patch in
   reverse order.
3. Never use `git checkout -- <files>` / `git restore <files>` /
   `git reset --hard` on a path that contains user uncommitted work.
4. Add a comment next to the rollback call explaining why `checkout` is
   not an option, so a future edit does not "simplify" it back.

**What was tried:** The /ship Step 0.5 revert path originally read:
"revert the patches (`git checkout -- <files>`) and stop with the error."
The code-reviewer agent flagged this as FAIL because the working tree
always has uncommitted changes at that point (that is the reason /ship
was invoked). Fixed to use `git apply -R <patch>` in reverse order with an
explicit **NOT `git checkout`** warning inline.
