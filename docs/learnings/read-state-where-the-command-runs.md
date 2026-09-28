# A guard reads repo state where the command runs

**Learned:** 2026-09-28 · **From:** /debug on block-dangerous.sh

`block-dangerous.sh` asked `CLAUDE_PROJECT_DIR` for the branch, so a session
on `main` could not commit in a feature worktree with `cd <wt> && git commit`
or `git -C <wt> commit`, and a session in a worktree could commit onto `main`
through either. `secret-scan.sh` had the same root: it scanned the session's
staged diff, so a secret staged in a worktree went through unscanned.

## The rule

A guard that judges repo state — the branch, the staged diff — reads it in
the directory the command runs in: the hook payload's `cwd`, moved by any
`cd` or `pushd` before the git call and by git's `-C`
(`lib/git-command.py --dir <base>`). A directory the text cannot say falls
back to the start, never to a guess. Test it with a worktree beside `main`,
in both directions.
