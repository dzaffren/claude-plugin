# Do not kill a subshell just after its fork when the parent has an EXIT trap

**Learned:** 2026-11-09 · **From:** portable-suite build

`run.sh` started a watchdog subshell for each test file, and killed it as soon
as the file ended. In 3 of 40 runs the watchdog died before bash had reset its
traps, so it ran the parent's `trap 'rm -rf "$work"' EXIT`. The next file then
lost its results file.

## The rule

Let a helper subshell end by itself, for example by a check that the job is
still alive. A guard on `$BASHPID` is not a fix: macOS `/bin/bash` 3.2 has no
`BASHPID`.
