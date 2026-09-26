# Run helpers long text

**Version:** v1 · **Status:** Built · **Type:** Bug · **Project type:** CLI/Library

**Depends on:** None

`run.sh`'s `expect_match` and `expect_no_match` misread any text longer than
64 KB whose match comes early. Found during the owasp-lens build; fixed through
`/debug`.

## Problem

Under `set -o pipefail` (`plugins/zuko/scripts/tests/run.sh:8`), the helpers ran
`printf '%s\n' "$2" | grep -qE "$1"`. `grep -q` exits at the first match. On
text past the 64 KB pipe buffer, `printf` is still writing, gets SIGPIPE and
exits 141, so the pipeline reports 141. A real match then reads as a miss:
`expect_match` fails, and `expect_no_match` passes on text that matches. The bug
dates from `5134693` (2026-09-12).

```
printf "$text" ─pipe─> grep -q NEEDLE      match on line 1, so grep exits 0
      │                                     and the pipe closes early
      └─ 200 KB still to write, so SIGPIPE, exit 141
pipefail makes the pipeline 141: expect_match FAIL, expect_no_match PASS
```

## Slice test

| Check                         | Result                                                   |
| ----------------------------- | -------------------------------------------------------- |
| Cuts every layer it needs     | yes — the two helpers                                    |
| One e2e test walks it         | yes — `test-run-helpers.sh` runs both helpers end to end |
| Worth shipping alone          | yes — every check on long output means what it says      |
| Fits (≤5 scenarios, ≤2 areas) | yes — 1 scenario, 1 file                                 |

**Path:** light — a bug fix in one file, with no new interface, data or
dependency.

## Acceptance criteria

```gherkin
Scenario: the match helpers read long text correctly
  Given a 200 KB text whose first line is "NEEDLE"
  When expect_match NEEDLE runs on it
  Then it records PASS
  And expect_no_match NEEDLE on the same text records FAIL
  And on a 200 KB text with no match, expect_match records FAIL
    and expect_no_match records PASS
```

## Technical plan

### Changes

| File                                                   | What changes                                                                                      |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| `plugins/zuko/scripts/tests/run.sh:22-33`              | grep reads the text from a here-string, `grep -qE "$1" <<<"$2"`, not a pipe                       |
| `plugins/zuko/scripts/tests/test-run-helpers.sh` (new) | 5 checks on short, long-match and long-miss text, each helper's record captured in a scratch file |

### Non-functionals

|                      |                                                                        |
| -------------------- | ---------------------------------------------------------------------- |
| **Load**             | the test harness only                                                  |
| **Breaks first**     | nothing: a here-string holds any size bash can hold in a variable      |
| **Security surface** | none; test code only                                                   |
| **Proof it works**   | `bash plugins/zuko/scripts/tests/run.sh run-helpers` prints `5 passed` |
| **Rollout**          | no flag: test harness code. Rollback is `git revert` of the fix commit |

### Test plan

**E2E:** `bash plugins/zuko/scripts/tests/run.sh run-helpers`. It failed 2 of 5
before the fix and passes 5 of 5 after. The full suite gives 1232 passed,
0 failed. Run with the fixed helpers, the pre-existing 1227 checks gave the same
results, so no existing check was hiding a failure.

## Open items

| ID  | What                                                 | Type     | Raised at | Owner  | Status   | Answer                                                                           |
| --- | ---------------------------------------------------- | -------- | --------- | ------ | -------- | -------------------------------------------------------------------------------- |
| O1  | Did any existing test pass only because of this bug? | question | /debug    | claude | Resolved | No: the full suite with the fixed helpers gave the same 1227 passes (2026-09-26) |

_Never delete this section or its rows. See references/ledger.md._
