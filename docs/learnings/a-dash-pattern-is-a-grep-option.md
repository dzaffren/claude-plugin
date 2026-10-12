# A pattern that starts with a dash is a grep option

**Learned:** 2026-10-12 · **From:** /build ste-voice, then /debug

`run.sh`'s helpers ran `grep -qE "$1"`. A pattern such as
`'- code, commands and paths'` starts with `-`, so grep read it as an option.
grep printed "invalid option" and exited 2. `expect_match` then recorded
"nothing matched", before the code existed and after it. `expect_no_match` was
worse: it recorded a pass on text that did match, and printed no failure.

## The rule

Pass a caller's pattern to grep with `-e`. Read a test's first red run for
grep errors, not only for FAIL lines.

`run.sh` uses `grep -qE -e "$1"`. The regression test is in
`scripts/tests/test-run-helpers.sh`.
