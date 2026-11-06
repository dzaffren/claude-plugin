# Git Bash rewrites a path-like value before a native program sees it

**Learned:** 2026-11-01 · **From:** /build rendered-drift-check

Git Bash (MSYS) converts arguments and environment values that look like
POSIX paths when it starts a native Windows program such as `node.exe`. The
e2e set `CHROME_PATH=/no/chrome`, and Node read
`C:/Program Files/Git/no/chrome`. The gate was right: it exited 2 and refused
to fall back to another browser. Only the echoed path differed, so the exact
text match failed.

The other way round, a value that does not look like a path is passed as it
is: `/c/Users/...` in a custom variable such as `ZUKO_TOKEN_FILES` reached
Node unconverted, and Windows Node cannot open it.

## The rule

Hand a native program Windows paths that you made yourself (`cygpath -m`).
In a test, match an echoed path by its tail, as in `(/|[A-Z]:/.*/)no/chrome`,
and not by the exact POSIX text.
