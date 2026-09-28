# zsh does not word-split an unquoted variable in a for loop

**Learned:** 2026-09-28 · **From:** /ship regression-review

The session shell is zsh. `for c in $commits` over a newline-separated list of
shas ran once with the whole list as one word: `git cherry-pick` failed, and a
`case` on `7eeca46*` still matched the joined string, so the loop amended the
wrong commit. A backup branch made it a two-minute recovery.

## The rule

A multi-step git replay goes in a script file run with `bash <file>` — the
hook blocks `bash -c`. Make a backup branch first, and end with
`git diff --quiet backup HEAD` deciding the result, never an unconditional
echo.
