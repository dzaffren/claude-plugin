# A guard's fallback is safe only for input that cannot run

**Learned:** 2026-10-13 · **From:** tokenise-linear review

tokenise-linear made the shared parser refuse a command over 64 KB, so each
guard would take its cannot-parse path. The spec called that path safe
without a test. `block-dangerous.sh`, `secret-scan.sh` and
`block-attribution.sh` fall back to raw-text patterns, which miss
`git -C . push --force`, `cd other && git commit` and a `-F` message file.
The review proved all three let a long command through. The fallback had been
safe only because what reached it before, such as an unbalanced quote, is text
that bash cannot run either.

## The rule

Before a change sends new input down a guard's fallback, ask whether that
input runs. Input that runs gets the full check or a block, never a weaker
check. Prove it with the forms the full check handles: send each one, padded
past the new limit, and expect a block.

## The premise was wrong too (2026-10-13, fail-closed-parse)

"Text that bash cannot run either" was not true. bash runs each line before
an unclosed quote, and runs an unclosed heredoc to the end of the text, with a
warning. A comment with an apostrophe, which bash ignores, also sent a command
to the raw-text check. block-dangerous.sh now blocks each command that the
parser refuses (D52). Test the premise in bash before you build on it.
