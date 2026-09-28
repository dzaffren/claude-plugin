# Guard worktree dir

**Version:** v1 · **Status:** Built · **Type:** Bug · **Project type:** CLI/Library

**Depends on:** None

`block-dangerous.sh` and `secret-scan.sh` judged a commit by the session's
directory, not the one the commit runs in. Found while shipping pr-attribution
from a worktree; fixed through `/debug`.

## Problem

Both hooks read repo state from `${CLAUDE_PROJECT_DIR:-$PWD}`
(`block-dangerous.sh:34`, `secret-scan.sh:19`) and ignored the payload's
`cwd`, any `cd` before the git call, and git's `-C`. `lib/git-command.py`
dropped `-C` on its way to the subcommand. So a session on `main` could not
commit in a feature worktree, a session in a worktree could commit onto
`main`, and a secret staged in a worktree went unscanned. The branch check
dates from `40558c2` (2026-09-09).

```
"git -C <wt> commit"  or  "cd <wt> && git commit"
      │
      ▼
git-command.py        drops -C; the cd is a separate command
      │  "commit -m ..."
      ▼
block-dangerous.sh    git -C $CLAUDE_PROJECT_DIR symbolic-ref  →  main  →  deny
secret-scan.sh        git -C $CLAUDE_PROJECT_DIR diff --cached →  wrong diff scanned
```

## Slice test

| Check                         | Result                                                          |
| ----------------------------- | --------------------------------------------------------------- |
| Cuts every layer it needs     | yes — the parser and the two hooks that judge a commit          |
| One e2e test walks it         | yes — both hooks' tests run them on a worktree beside `main`    |
| Worth shipping alone          | yes — worktree builds can commit, and their secrets are scanned |
| Fits (≤5 scenarios, ≤2 areas) | yes — 3 scenarios, 1 area (hook scripts)                        |

**Path:** light — a bug fix inside the hook scripts, with an opt-in parser
mode and no change to any other consumer.

## Acceptance criteria

```gherkin
Scenario: a commit is judged on the branch it lands on
  Given a repo on main and a worktree on feat/wt beside it
  When the session on main runs "cd <wt> && git commit" or "git -C <wt> commit"
  Then block-dangerous.sh allows it
  And from the worktree, "cd <main> && git commit" or "git -C <main> commit"
    is blocked

Scenario: a directory the text cannot say falls back to the session's
  Given the session on main
  When the commit follows cd "$VAR", a cd into a missing directory,
    a cd inside ( … ), or a GIT_DIR= prefix
  Then the commit is judged on main and blocked, as before

Scenario: the secret scan reads the diff the commit takes
  Given a key-shaped value staged in the worktree
  When the commit runs there by the hook's cwd, by cd, or by -C
  Then secret-scan.sh blocks it
  And a commit pointed at the clean repo passes
```

## Technical plan

### Changes

| File                                                   | What changes                                                                                                                                                  |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `plugins/zuko/scripts/lib/git-command.py`              | opt-in `--dir <base>`: each line is `<dir>\t<args>`, dir from earlier `cd`/`pushd` (scoped to `( … )`) and `-C`; empty when unknown. Default output unchanged |
| `plugins/zuko/scripts/block-dangerous.sh`              | start from the payload `cwd`; check the branch of each commit's own directory, empty falling back to the start                                                |
| `plugins/zuko/scripts/secret-scan.sh`                  | same start; scan the staged diff in each commit's directory                                                                                                   |
| `plugins/zuko/scripts/tests/test-block-dangerous.sh`   | a worktree beside `main`; 10 cases both ways and the fall-backs                                                                                               |
| `plugins/zuko/scripts/tests/test-secret-scan.sh` (new) | 5 cases: a secret staged in the worktree, reached by cwd, `cd` and `-C`, and the clean repo                                                                   |

### Non-functionals

|                      |                                                                                                                 |
| -------------------- | --------------------------------------------------------------------------------------------------------------- |
| **Load**             | one more `python3` parse per Bash call that contains a commit                                                   |
| **Breaks first**     | a `GIT_DIR=` override still falls back to the start, so from a worktree it can reach `main` unjudged, as before |
| **Security surface** | two guards; the change closes a false allow in each and the old-versus-new diff found no new one                |
| **Proof it works**   | `bash plugins/zuko/scripts/tests/run.sh block-dangerous` prints `17 passed`; `secret-scan` prints `5 passed`    |
| **Rollout**          | no flag: hook scripts. Rollback is `git revert` of the two fix commits                                          |

### Test plan

**E2E:** `bash plugins/zuko/scripts/tests/run.sh block-dangerous` and
`... secret-scan`. Before the fix they failed 4 of 17 and 3 of 5; after, both
pass in full. The full suite gives 1731 passed, 0 failed. The old and new
`block-dangerous.sh` were run on the same 30 commands from both `main` and the
worktree: 9 verdicts moved from block to allow, every one a commit landing off
`main`, and 4 from allow to block, every one a commit landing on `main`.

## Open items

| ID  | What                                                     | Type     | Raised at | Owner  | Status   | Answer                                                                                  |
| --- | -------------------------------------------------------- | -------- | --------- | ------ | -------- | --------------------------------------------------------------------------------------- |
| O1  | Does the narrower check let through anything it blocked? | question | /debug    | claude | Resolved | No: the 30-command diff moved only commits that land off `main` to allow (2026-09-28)   |
| O2  | Should a `GIT_DIR=` override be blocked outright?        | question | /debug    | claude | Resolved | No: it falls back to the start as before, not a regression; recorded under Breaks first |

_Never delete this section or its rows. See references/ledger.md._
