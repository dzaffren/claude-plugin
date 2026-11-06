# Git Bash's grep cannot see a CR

**Learned:** 2026-11-07 · **From:** /build lf-checkout

Git Bash's grep strips a CR at each line end before it matches. So
`grep -q $'\r' file` finds nothing in a CRLF file on Windows, and a check for a
CR passes when the CR is there. The first draft of `test-e2e-lf-checkout.sh`
passed its CR checks before the fix existed. `git ls-files --eol` showed the
files as `w/crlf` at the same time.

The other way round, `expect_match` and `expect_no_match` use grep, so a test
that matches CRLF text on Windows ignores the `\r` that a reader such as
`read -r` keeps.

## The rule

Test for a CR with a bash pattern, `[[ $text == *$'\r'* ]]`, or with
`git ls-files --eol`. Never with grep. Watch a CR check fail before the fix,
on Windows.
