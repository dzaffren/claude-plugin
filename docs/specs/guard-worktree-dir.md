# Guard worktree dir

**Version:** v1 · **Status:** Shipped · **Type:** Bug · **Project type:** CLI/Library

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

Scenario: a move the text cannot prove is judged everywhere it could land
  Given the project dir on main, and the hook's cwd on main or in the worktree
  When the commit follows a cd the shell may not keep for it (popd, a pipe,
    &, backticks, a failed &&, braces, an if), cd "$VAR", cd --,
    a missing directory, GIT_DIR= or --git-dir
  Then both the cwd and the project dir are checked, and the commit is
    blocked, never looser than the old project-dir check

Scenario: the secret scan reads the diff the commit takes
  Given a key-shaped value staged in the worktree
  When the commit runs there by the hook's cwd, by cd, or by -C
  Then secret-scan.sh blocks it
  And a commit pointed at the clean repo passes
```

## Technical plan

### Changes

| File                                                   | What changes                                                                                                                                                                                                                             |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `plugins/zuko/scripts/lib/git-command.py`              | opt-in `--dir <base>`: each line is `<dir>\t<args>`, dir from a `cd`/`pushd` in a plain `&&` chain from the start, then `-C`; empty after any other separator following a move, a `popd`, or an untracked `cd`. Default output unchanged |
| `plugins/zuko/scripts/block-dangerous.sh`              | start from the payload `cwd`; check the branch of each commit's own directory; an empty one checks both the `cwd` and the project dir                                                                                                    |
| `plugins/zuko/scripts/secret-scan.sh`                  | same start; scan the staged diff in each commit's directory; an empty one scans both                                                                                                                                                     |
| `plugins/zuko/scripts/tests/test-block-dangerous.sh`   | a worktree beside `main`; 22 cases both ways, the moves the shell does not keep, and the fall-backs                                                                                                                                      |
| `plugins/zuko/scripts/tests/test-secret-scan.sh` (new) | 8 cases: a secret staged in the worktree reached by cwd, `cd` and `-C`; one staged in the project repo reached by `cd --`, `cd "$R"` and `pushd`/`popd`                                                                                  |

### Non-functionals

|                      |                                                                                                                                                            |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Load**             | one more `python3` parse per Bash call that contains a commit                                                                                              |
| **Breaks first**     | a `GIT_DIR=` override into a third repo on `main`, from a session whose cwd and project dir are both off `main`: neither candidate is on `main`, as before |
| **Security surface** | two guards; the change closes a false allow in each. An unknown directory checks the cwd and the project dir, so no verdict is looser than the old one     |
| **Proof it works**   | `bash plugins/zuko/scripts/tests/run.sh block-dangerous` prints `29 passed`; `secret-scan` prints `8 passed`                                               |
| **Rollout**          | no flag: hook scripts. Rollback is `git revert` of the five fix commits                                                                                    |

### Test plan

**E2E:** `bash plugins/zuko/scripts/tests/run.sh block-dangerous` and
`... secret-scan`. Before the first fix they failed 4 of 17 and 3 of 5. The
review's 14 cases then failed against that fix and pass after the second. Both
now pass in full, and the full suite gives 1746 passed, 0 failed. The old
(`8d2d6b4`) and new `block-dangerous.sh` were run on the same 41 commands, with
the project dir on `main` and the cwd on `main` and in the worktree: 16
verdicts moved from block to allow, every one a commit that lands in the
worktree or outside a repo, and none that lands on `main`.

## Open items

| ID  | What                                                     | Type     | Raised at | Owner  | Status   | Answer                                                                                                                                                                                                                               |
| --- | -------------------------------------------------------- | -------- | --------- | ------ | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| O1  | Does the narrower check let through anything it blocked? | question | /debug    | claude | Resolved | First answer was wrong: /review found popd, pipes, `&`, backticks, braces and a cwd-only fall-back let commits onto `main` through. After the fix, the 41-command diff moves only commits that land off `main` to allow (2026-09-29) |
| O2  | Should a `GIT_DIR=` override be blocked outright?        | question | /debug    | claude | Resolved | No: an unknown directory now checks the cwd and the project dir, which blocks it whenever either is on `main`; the rest is under Breaks first                                                                                        |

_Never delete this section or its rows. See references/ledger.md._
