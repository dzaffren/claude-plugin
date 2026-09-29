# A guard reads repo state where the command runs

**Learned:** 2026-09-28 · **From:** /debug on block-dangerous.sh

`block-dangerous.sh` asked `CLAUDE_PROJECT_DIR` for the branch, so a session
on `main` could not commit in a feature worktree with `cd <wt> && git commit`
or `git -C <wt> commit`, and a session in a worktree could commit onto `main`
through either. `secret-scan.sh` had the same root: it scanned the session's
staged diff, so a secret staged in a worktree went through unscanned.

## The rule

A guard that judges repo state — the branch, the staged diff — reads it in
the directory the command runs in: the hook payload's `cwd`, moved by git's
`-C` and by a `cd` or `pushd` only where the shell is sure to keep it, a plain
`&&` chain (`lib/git-command.py --dir <base>`). A pipe, `&`, `;`, backticks,
`popd`, braces or an `if` after a move make the directory unknown, and an
unknown one is judged in every place it could be — the `cwd` and the project
dir — so the new check is never looser than the old. The first version
trusted every `cd` and fell back to the `cwd` alone; /review found 14 ways
onto `main` through it. Diff old against new with the project dir and the
`cwd` set apart, not equal, or half the cases never run.
