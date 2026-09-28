# Branch from main by name, not from HEAD

**Learned:** 2026-09-28 · **From:** pr-attribution build

The session started on `main`, but before `/build` ran `git switch -c
feat/pr-attribution`, another session in the same checkout had switched it to
`feat/ledger-handoff`. The new branch took that HEAD, so three `ledger-handoff`
commits sat under a slice that depends on nothing. It surfaced only when
`git status` showed files neither session's plan named. The fix was a
cherry-pick replay onto `main` behind a backup branch, then a diff proving only
the base moved.

## The rule

Name the base: `git switch -c {type}/{slice} main`, never a bare `-c` off
whatever HEAD is. Before the first commit, check `git log main..HEAD` is empty.
When `git status` shows changes your plan never named, another session shares
the checkout. Stage your own files by path, and never commit or stash theirs.
