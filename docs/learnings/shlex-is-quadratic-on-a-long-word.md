# Python's shlex is quadratic on a long word

**Learned:** 2026-10-13 · **From:** debug of the flaky scope-verifier-bash test

`git-command.py`'s `tokenise` is `shlex.shlex`. Python 3.9's `shlex.py` grows
each token with `self.token += nextchar`, which copies the whole token for
every character. A 100 KB word took 0.20 s, 200 KB 0.55 s and 400 KB 2.17 s.
A 1.1 MB `git show main:aaa…` took 19.6 s in `scope-verifier-bash.sh` and
21 s in `block-dangerous.sh`, so the test's 20 s alarm failed about one run in
two, and `release.py plan` refused the release.

A hook that runs past its timeout does not block the tool call: "A timed-out
`command`, `http`, or `mcp_tool` hook doesn't block the tool call"
(code.claude.com/docs/en/hooks, Timeouts; the default is 600 s). A guard that
is slow on large input is a guard that a large enough input walks past.

## The rule

Time a guard on its largest input, at two sizes, before you set an alarm in
its test. Twice the input in four times the time is quadratic. Fix the cost,
or cap the input and fail closed, before you raise the alarm.
