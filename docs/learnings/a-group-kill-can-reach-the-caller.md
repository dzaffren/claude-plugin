# A group kill can reach the caller

**Learned:** 2026-11-09 · **From:** zuko /build windows-ci (PR #136)

`stop_tree` sent `kill -TERM -- -$pid` and relied on it to fail when the pid
did not lead its own group, so that a plain `kill` followed. Inside a test
file, `set -o monitor` is on but job control is not active, so a background
job shares the test file's process group. On `ubuntu-latest`, bash's `kill`
signalled the job's group for `-pid`, which was the test file itself, and the
file died with 143 after two checks. On this machine's older bash, the same
call failed as intended, so the bug showed only in CI.

## The rule

Signal a process group only after checking that the pid leads it:
`[ "$(ps -o pgid= -p "$pid" | tr -d ' ')" = "$pid" ]`. A group kill that is
expected to fail is not a safe fallback. When a test stops with 143 in CI
and passes locally, log `ps -eo pid,ppid,pgid,cmd` at the kill before you
guess.
