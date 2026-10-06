# A gate with no test of its own may never have run

**Learned:** 2026-10-06 · **From:** /debug design-drift-filename (pentest P2)

`check-design-drift.sh` had no test file. Debugging pentest P2 showed it had
never parsed under macOS's `/bin/bash` 3.2, the `bash` that `/spec`, `/design`
and `/review` call it with: a bare `case` pattern inside `$( )` reads its `)`
as the end of the substitution. Every run since the zuko 2.0.0 rebuild exited
2 before scanning a file. The pentester only saw P2 because it had bash 5 on
its `PATH`.

## The rule

Every gate script gets a `tests/test-<name>.sh` that runs it with
`/bin/bash` where that exists, and parses it with `/bin/bash -n`. `run.sh`
alone is not enough: its shebang is `#!/usr/bin/env bash`, so with Homebrew's
bash first on `PATH` a script bash 3.2 cannot parse still tests green. In a `case` inside
`$( )`, write the pattern with its leading paren: `(*.css) …`. See
[[gate-scanned-nothing-is-not-a-pass]].
