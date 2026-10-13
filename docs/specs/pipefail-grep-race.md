# Pipefail grep race

**Version:** v1 · **Status:** Shipped · **Type:** Bug · **Project type:** CLI/Library

**Depends on:** None. This closes O4 of `fail-closed-parse`.

The hook and gate scripts give `grep -q` its text with a here-string, not a
pipe. A pipe let a slow `printf` turn a match into a miss, so a force push, a
commit on main and a staged secret could pass. Fixed through `/debug`.

## Problem

Under `set -o pipefail`, 14 checks in five scripts piped text into `grep -q`.
bash's `printf` writes to a pipe one line at a time. strace showed
`write(1, "push origin main\n", 17)`, then `write(1, "status\n", 7)`. `grep -q` exits
at its first match. When it exits before the next write, that write gets
SIGPIPE, and `printf` exits 141. pipefail makes the pipeline's status 141, and
the `if` reads the match as a miss.

Each row ran on `main` at `4ef85fe` on 2026-10-13, with bash 5.1.8. It ran once
as it is, and once with strace pausing a write for 0.3 s:

| Site                        | Input                                                    | Right answer      | As it is | Paused             |
| --------------------------- | -------------------------------------------------------- | ----------------- | -------- | ------------------ |
| `block-dangerous.sh:40`     | `git push --force origin main; git status`               | exit 2            | 2        | 0                  |
| `block-dangerous.sh:44`     | `git push origin ma?n; git status`                       | exit 2            | 2        | 0                  |
| `block-dangerous.sh:48`     | `rm -rf ..`, then a second line                          | exit 2            | 2        | 0                  |
| `block-dangerous.sh:83`     | `git commit -m x; git status`, on main                   | exit 2            | 2        | 0                  |
| `secret-scan.sh:23`         | `git commit -m x; git status`, with a key staged         | exit 2            | 2        | 0                  |
| `check-design-drift.sh:141` | a CSS file that uses only a known token                  | exit 0            | 0        | 1, token "unknown" |
| `verify-ship-gates.sh:208`  | a commit with a session trailer, then one more line      | names the trailer | names it | does not name it   |

Each paused run had one process killed by SIGPIPE. Without strace, a busy
machine can pause `printf` too. O4 of `fail-closed-parse` records one
full-suite run that most likely failed this way.

```
printf '%s\n' "$git_args"                      grep -qE "$push_re"
  | write 1: "push --force origin main\n" --pipe--> match: exit 0, pipe closes
  | (printf paused here)
  | write 2: "status\n" --> no reader: SIGPIPE, printf exits 141
  v
pipefail: the pipeline returns 141, its last non-zero status
  |
  v
if reads 141 as no match --> deny never runs, block-dangerous.sh exits 0
```

Five of the 14 sites get one line only. They cannot race in practice: with
every write paused, a 20 KB line in two writes gave no SIGPIPE.

## Slice test

| Check                         | Result                                                                  |
| ----------------------------- | ----------------------------------------------------------------------- |
| Cuts every layer it needs     | yes — five scripts and two test files                                   |
| One e2e test walks it         | by hand — the strace probe runs the real hooks; the suite holds the rule with a static check (O1) |
| Worth shipping alone          | yes — closes a force-push bypass and a staged-secret bypass             |
| Fits (≤5 scenarios, ≤2 areas) | yes — 4 scenarios, 1 area (hook and gate scripts)                       |

**Path:** light — a one-line change at each site, plus a test, with no new
interface, data or dependency.

## Acceptance criteria

```gherkin
Scenario: a guard blocks a force push when printf is slow
  Given the command git push --force origin main; git status
  And strace pauses each process for 0.3 s after its first write
  When block-dangerous.sh reads it
  Then it exits 2

Scenario: the commit checks and the gates read every line when printf is slow
  Given git commit -m x; git status with a key staged, for secret-scan.sh
  Or a CSS file that uses only a known token, for check-design-drift.sh
  Or a commit with a session trailer before its last line, for verify-ship-gates.sh
  When strace pauses printf after the matching line
  Then secret-scan.sh exits 2
  And check-design-drift.sh exits 0
  And verify-ship-gates.sh names the trailer

Scenario: no script with pipefail pipes text into grep -q
  Given each script in plugins/zuko/scripts/ that sets pipefail
  When test-secret-scan.sh reads it
  Then no line pipes into grep with -q, --quiet or --silent

Scenario: every other check gives the same answer
  When the full suite runs
  Then every check passes, as on main
```

## Scope

**In:** the 14 piped `grep -q` checks in `block-dangerous.sh`,
`secret-scan.sh`, `check-design-drift.sh`, `verify-gates.sh` and
`verify-ship-gates.sh`; one test check with the same race; the static check.

**Out:**

- `block-attribution.sh` pipes into `grep -iE` with no `-q`. That `grep` reads
  all of its input, so `printf` cannot get SIGPIPE. Its status ends in
  `|| true` too.
- A pipe into `head` can kill the writer too, for example at
  `verify-gates.sh:30`. No script reads the status of one: each sits in an
  assignment or ends in `|| true`.
- `test-release.sh:795` pipes one byte into `grep -qx`, in one write. The
  static check reads `scripts/*.sh`, not `tests/`.

## Technical plan

### Approach

Each `printf '%s\n' "$x" | grep -qE "$re"` becomes `grep -qE "$re" <<<"$x"`.
bash writes a here-string in full before `grep` starts. strace on bash 5.1.8
showed both forms. A 24-byte text went into a pipe, in the process that then
runs `grep`. An 85 KB text went into a temp file. No other process writes, so
none can die of SIGPIPE, and the status is the status of `grep`.

The bytes stay the same. A here-string adds one newline, as `printf '%s\n'`
does. `printf '%s'` adds none, and `grep` reads a last line without a newline
in the same way. The two forms differ only for a pattern that matches an empty
line. None of the five `printf '%s'` sites has one.

Relies on: none.

### Changes

| File                                                          | What changes                                                       | Why           |
| ------------------------------------------------------------- | ------------------------------------------------------------------ | ------------- |
| `plugins/zuko/scripts/block-dangerous.sh:40, 44, 48, 83, 89`  | the push, glob, `rm` and commit checks read a here-string          | scenarios 1, 3 |
| `plugins/zuko/scripts/secret-scan.sh:23, 34`                  | the commit checks read a here-string                               | scenarios 2, 3 |
| `plugins/zuko/scripts/check-design-drift.sh:141`              | the known-token check reads a here-string                          | scenarios 2, 3 |
| `plugins/zuko/scripts/verify-gates.sh:38`                     | the `-vN` name check reads a here-string                           | scenario 3     |
| `plugins/zuko/scripts/verify-ship-gates.sh:146, 196, 208, 212, 216` | the branch, subject and attribution checks read a here-string | scenarios 2, 3 |
| `plugins/zuko/scripts/tests/test-owasp-lens.sh:51`            | the section check reads a here-string (O3)                         | scenario 4     |
| `plugins/zuko/scripts/tests/test-secret-scan.sh:68-81`        | a static check of each script with pipefail                        | scenario 3     |

### Non-functionals

|                      |                                                                                                   |
| -------------------- | ------------------------------------------------------------------------------------------------- |
| **Load**             | one process fewer for each check: no `printf` subshell                                            |
| **Breaks first**     | a here-string can need a temp file. With no temp directory that bash can write, `grep` does not run, and the check reads as a miss (O5) |
| **Security surface** | closes O4 of `fail-closed-parse`: a slow `printf` let a force push, a commit on main and a staged secret pass |
| **Proof it works**   | `bash plugins/zuko/scripts/tests/run.sh secret-scan` gives 26 passed. With the strace pause, all 7 inputs give the right answer |
| **Rollout**          | no flag: hook and gate scripts. Rollback is `git revert 67716f9`                                  |

### Test plan

**E2E:** by hand, the strace probe feeds each input in the Problem table to
the real script. It runs the script under
`strace -f -e inject=write:delay_exit=300000:when=1`. The session-trailer case
pauses every write, with `when=1+`. On `main`, all 7 paused runs gave the wrong
answer. After the fix, all 7 give the right answer, and no process gets
SIGPIPE.

**Suite:** the static check in `test-secret-scan.sh` failed 5 of 16 scripts
before the fix, and named all 14 lines. After the fix, `run.sh secret-scan`
gives 26 passed. The full suite gives 2416 passed, 0 failed.

### Decisions to record

Recorded as D57.

## Review

2026-10-13 · 0 raw findings, 0 survived. Clean.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | A timing race needs strace to force it. strace is not on macOS, and the suite also runs on macOS's /bin/bash 3.2. | flag | /debug | user | Decided alone | Chose: a static check in `test-secret-scan.sh` that fails a script with pipefail that pipes into `grep -q`. It runs everywhere, and it also finds a new site that no test feeds. The strace proof stays a manual step. Other: a strace test that runs only where strace works. Undo: add a strace check to `test-secret-scan.sh` that runs only when `command -v strace` succeeds. 2026-10-13 |
| O2 | Five sites get one line only, and cannot race in practice: `block-dangerous.sh:89`, `secret-scan.sh:34`, `verify-gates.sh:38`, `verify-ship-gates.sh:146` and `:196`. | flag | /debug | user | Decided alone | Chose: change all 14 sites, so the static check has no exceptions. Other: change only the 9 sites with more than one line, and let the check skip the other 5. Undo: put back the pipe at those 5 lines, and add a skip list to the check. 2026-10-13 |
| O3 | `test-owasp-lens.sh:51` piped a category section into `grep -qF` under the pipefail of `run.sh`. A slow `printf` there gives a false FAIL in the suite. | flag | /debug | user | Decided alone | Chose: change it to a here-string in the fix commit. Other: leave it, and fix it in a separate change. Undo: put back the pipe at `test-owasp-lens.sh:51`. 2026-10-13 |
| O4 | Not run on macOS's /bin/bash 3.2: this machine has bash 5.1.8 only. bash has had here-strings since 2.05b, and `block-dangerous.sh:91` and `secret-scan.sh:35` already use them. | flag | /debug | user | Decided alone | Chose: ship without a bash 3.2 run. Other: run the suite on a Mac first. Undo: run `/bin/bash plugins/zuko/scripts/tests/run.sh` on a Mac, then `git revert 67716f9` if it fails. 2026-10-13 |
| O5 | bash before 5.1 writes each here-string to a temp file. If bash cannot write one, `grep` does not run, and the check reads as a miss. On macOS, the push checks did not need a temp file before. | flag | /debug | user | Decided alone | Chose: the here-string, as `run.sh:26` and `block-dangerous.sh:91` already use. Other: process substitution, which reads from a pipe and needs no temp file, but which lets `printf` die unseen. Not run on bash 3.2. Undo: change each site to `grep -qE "$re" < <(printf '%s\n' "$x")`. 2026-10-13 |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **pipefail** — a bash option: a pipeline fails when any of its commands fails, not only the last one
- **SIGPIPE** — the signal a process gets when it writes to a pipe with no reader. By default it kills the process, with exit status 141
- **Here-string** — `cmd <<<"$x"` gives the text of `$x`, plus a newline, to the input of `cmd`, with no pipeline
- **strace** — a Linux tool that shows the system calls of a process. With `inject`, it can also pause one
- **e2e** — end-to-end: one test that walks the whole slice as a user would
