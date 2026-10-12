# A pattern that starts with a dash is a grep option

**Learned:** 2026-10-12 · **From:** /build ste-voice

`run.sh`'s `expect_match` runs `grep -qE "$1"`. A pattern such as
`'- code, commands and paths'` starts with `-`, so grep reads it as an option.
grep prints "invalid option" and exits 2, and the helper records "nothing
matched". The check fails before the code exists and after it, so its first
red run proves nothing.

## The rule

When a pattern starts with `-`, write the dash as `[-]`. Read a test's first
red run for grep errors, not only for FAIL lines.

A fix in the helpers, `grep -qE -e "$1"`, would close this for every test. It
is not made yet.
