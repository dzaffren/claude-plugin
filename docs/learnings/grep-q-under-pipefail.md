# Never pipe into `grep -q` under `pipefail`

**Learned:** 2026-09-26 · **From:** /debug of run.sh's match helpers

`run.sh` sets `set -o pipefail`, and its `expect_match` and `expect_no_match`
ran `printf '%s\n' "$2" | grep -qE "$1"`. `grep -q` exits at the first match.
On text past the 64 KB pipe buffer, `printf` is still writing, gets SIGPIPE and
exits 141, and `pipefail` makes the whole pipeline 141. So a real match read as
a miss: `expect_match` failed, and `expect_no_match` passed on text that did
match, silently.

It hid for two weeks because no check happened to hand the helpers that much
text with an early match. The owasp-lens build hit it on a seeded-run stream.

## The rule

Give `grep -q` its input without a pipe: `grep -qE "$re" <<<"$text"`, or a file.
Under `pipefail`, any reader that can stop early (`grep -q`, `head`, `read`)
turns the writer's SIGPIPE into a failure of the pipeline.

The regression test is `scripts/tests/test-run-helpers.sh`. It runs each helper
on a 200 KB text with the match on its first line.
