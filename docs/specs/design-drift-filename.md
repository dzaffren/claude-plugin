# Design drift filename

**Version:** v1 · **Status:** Shipped · **Type:** Bug · **Project type:** CLI/Library

**Depends on:** None

`check-design-drift.sh` never parsed under macOS's `/bin/bash`, and under bash 5
it let a file name write a file. Found by the v2.2.0 pentest (P2); fixed through
`/debug`.

## Problem

The `/spec`, `/design` and `/review` stages call the gate as
`bash check-design-drift.sh <paths>`. On macOS that `bash` is 3.2.57, which reads
the bare `case` pattern at `check-design-drift.sh:43`, inside `$( )`, as the end
of the substitution. Every run exited 2 with a syntax error before it scanned a
file, since the zuko 2.0.0 rebuild (`40558c2`). The script had no test.

Under bash 5 it ran, and each of the six checks put the scanned file's name into
a `sed` program (`:73`, `:82`, `:91`, `:102`, `:111`, `:120`). A name holding
`|w <path>`, such as `x|w pwned|.css`, made BSD `sed` write an empty file and
mangled the report line.

```
bash 3.2 ── parse :43 ── bare "case …)" inside $( ) ──► syntax error, exit 2
bash 5   ── grep hit ── sed "s|^|$f:|" ── name "x|w pwned|.css" ──► sed writes "pwned|.css:|"
```

## Slice test

| Check                         | Result                                                      |
| ----------------------------- | ----------------------------------------------------------- |
| Cuts every layer it needs     | yes — the one gate script and its first test                |
| One e2e test walks it         | yes — `test-design-drift.sh` runs the script as stages do   |
| Worth shipping alone          | yes — the drift gate runs on macOS, and a name is only data |
| Fits (≤5 scenarios, ≤2 areas) | yes — 2 scenarios, 1 area (hook and gate scripts)           |

**Path:** light — a bug fix in one script plus its test, with no new
interface, data or dependency.

## Acceptance criteria

```gherkin
Scenario: the gate runs under macOS's bash
  Given docs/design/share/card.css holding ".card { color: #ff0000; }"
  When /bin/bash runs check-design-drift.sh docs/design/share
  Then it exits 1 and reports "docs/design/share/card.css:1:.card { color: #ff0000; }"
  And a file that uses only tokens is not reported

Scenario: a file name is data, never sed code
  Given docs/design/evil/x|w pwned|.css holding ".a { color: #ff0000; }"
  When check-design-drift.sh scans docs/design/evil
  Then it exits 1, reports the name whole, and writes no file
```

## Technical plan

### Changes

| File                                                    | What changes                                                                        |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `plugins/zuko/scripts/check-design-drift.sh:43` | the `case` pattern gets its leading paren, written `(*.html` and so on, which bash 3.2 parses inside `$( )` |
| `plugins/zuko/scripts/check-design-drift.sh` | a `prefix` function prints `<file>:<line>` with `printf`, replacing the six `sed` calls that built the file name into their program |
| `plugins/zuko/scripts/tests/test-design-drift.sh` (new) | the script's first test: an ordinary hit, a clean file, and the crafted name        |

### Non-functionals

|                      |                                                                                               |
| -------------------- | --------------------------------------------------------------------------------------------- |
| **Load**             | one `printf` per reported line instead of one `sed`; at most 5 hits per file per check        |
| **Breaks first**     | nothing new; the gate now scans on macOS, so UI slices that never met it may fail it for real |
| **Security surface** | removes a file write chosen by a scanned file's name (pentest P2)                             |
| **Proof it works**   | `bash plugins/zuko/scripts/tests/run.sh design-drift` prints `7 passed`, running the gate with `/bin/bash`     |
| **Rollout**          | no flag: a gate script. Rollback is `git revert` of the fix commit                            |

### Test plan

**E2E:** `bash plugins/zuko/scripts/tests/run.sh design-drift`. Before the fix
it failed 4 of 6 with exit 2 from the parse error; after the parse fix, the two
P2 cases failed (a file written, the name mangled); after both, 6 passed.
/review then added a `/bin/bash -n` parse check and pinned the runs to
`/bin/bash`, because `run.sh` uses whatever `bash` is first on `PATH`: 7 passed,
and with the parse bug restored under a Homebrew-first `PATH` it fails. The
full suite gives 1966 passed, 0 failed, and all 50 zuko scripts pass
`/bin/bash -n`.

## Open items

| ID  | What                                                                | Type     | Raised at | Owner  | Status   | Answer                                                                |
| --- | ------------------------------------------------------------------- | -------- | --------- | ------ | -------- | --------------------------------------------------------------------- |
| O1  | Does any other zuko script fail to parse under macOS's `/bin/bash`? | question | /debug    | claude | Resolved | No: all 50 `.sh` files pass `/bin/bash -n` after the fix (2026-10-06) |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **e2e** — end-to-end: one test that walks the whole slice as a user would
- **Pentest** — the security test `/release` runs on the code it ships; its
  findings are numbered P1, P2, …
