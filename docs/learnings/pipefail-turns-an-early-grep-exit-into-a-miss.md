# pipefail turns an early grep exit into a miss

**Learned:** 2026-10-13 · **From:** /build of fail-closed-parse

`block-dangerous.sh` runs with `set -o pipefail` and asks
`if printf '%s\n' "$x" | grep -qE "$re"`. bash's `printf` writes to a pipe one
line at a time (strace showed one `write` per line). `grep -q` exits on its
first match. When the match is on a line before the last, and `printf` is
paused between two writes, its next write gets SIGPIPE, the pipeline returns
141, and the `if` reads a match as no match. With `printf` paused 0.3 s after
its first line (strace `inject=write:delay_exit`), v2.3.1's guard passed
`git push --force origin main; git status`. Without the pause it blocked it.
Under load the pause happens by itself: one full-suite run failed a check
this way, and 300 runs of the same check alone did not.

## The rule

In a script with `pipefail`, never pipe text into `grep -q` for a yes or no.
Give `grep` the text with a here-string, `grep -qE "$re" <<<"$x"`, so no
writer can die. To prove a race like this, force the pause with strace
instead of looping and hoping.

## Now enforced (2026-10-13, pipefail-grep-race)

All 14 sites under `scripts/` now use a here-string, and a static check in
`tests/test-secret-scan.sh` fails any script with pipefail that pipes into
`grep -q`. To prove the race when the match is not on the first line, pause
every write: strace `inject=write:delay_exit=300000:when=1+`, not `when=1`.
