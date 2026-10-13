# gh create value options

**Version:** v1 · **Status:** Built · **Type:** Bug · **Project type:** CLI/Library

**Depends on:** `pr-edit-attribution` — its row O4 named this gap

The attribution hook gives each value-taking option of `gh pr create` and
`gh release create` its value, as it does for `gh pr edit` and `gh pr merge`.
A value option before the body or the notes no longer hides a signed text.
Found by the review of `pr-edit-attribution`; fixed through `/debug`.

## Problem

`read_options` in `block-attribution.sh` reads only the options in the table it
is given. The `gh pr create` table and the `gh release create` table held just
their three message options. A value option they did not know left its value
in the walk. A short one, such as `-Bnext`, read on into its value and took
the first `t`, `b`, `n` or `F` there as that option. A long one, such as
`--target`, was skipped, and its value was read as the next option. Either way
`-t` took the next flag as the title, and the signed text after it was skipped
as a positional. Each row was run as a real hook payload against `main` at
`4ef85fe` (v2.4.1) on 2026-10-13, with gh 2.101.0:

| Command | `main` | This fix |
| --- | --- | --- |
| `gh pr create -t x --body "<signed text>"` | exit 2 | exit 2 |
| `gh pr create -Bnext --body "<signed text>"` | exit 0 | exit 2 |
| `gh pr create -Hfeat -b "<signed text>"` | exit 0 | exit 2 |
| `gh pr create -mSprint -b "<signed text>"` | exit 0 | exit 2 |
| `gh pr create -Rowner/rept -b "<signed text>"` | exit 0 | exit 2 |
| `gh pr create -dBnext -b "<signed text>"` | exit 0 | exit 2 |
| `gh pr create --base -t --body "<signed text>"` | exit 0 | exit 2 |
| `gh pr create --label -t -b "<signed text>"` | exit 0 | exit 2 |
| `gh release create v2.4.1 -n "<signed text>"` | exit 2 | exit 2 |
| `gh release create v2.4.1 --target -t -n "<signed text>"` | exit 0 | exit 2 |
| `gh release create v2.4.1 --notes-start-tag -t -n "<signed text>"` | exit 0 | exit 2 |
| `gh release create v2.4.1 --discussion-category -t -n "<signed text>"` | exit 0 | exit 2 |
| `gh release create v2.4.1 --repo -t -n "<signed text>"` | exit 0 | exit 2 |
| `gh release create v2.4.1 -Ro/rept -n "<signed text>"` | exit 0 | exit 2 |
| `gh release -R o/r create v2.4.1 -n "<signed text>"` | exit 0 | exit 0, see O3 |

The traced path, with line numbers on `main`:

```
gh pr create -Bnext --body "<signed text>"   gh release create v2.4.1 --target -t -n "<signed text>"
      │                                              │
      ▼                                              ▼
create table :166-170 knows b, F, t only     release table :124-127 knows n, F, t only
      │                                              │
      ▼                                              ▼
short_options :61-63 skips B, n, e, x        read_options :100-101 skips --target
and stops at the t of "next"                 and leaves its value, so -t is next
      │                                              │
      └──────────────────────┬───────────────────────┘
                             ▼
      -t has an empty tail: :70-71 takes --body or -n as the title
                             │
                             ▼
      the signed text has no "-": read_options :90-103 skips it
                             │
                             ▼
      grep at :195 finds no banned line ──► exit 0, gh runs
```

## Slice test

| Check | Result |
| --- | --- |
| Cuts every layer it needs | yes. The hook's two option tables and its test. |
| One e2e test walks it | yes. `test-block-attribution.sh` sends real hook payloads to the real script. |
| Worth shipping alone | yes. It closes a way to put a signed PR body or release notes past the hook. |
| Fits (≤5 scenarios, ≤2 areas) | yes. 3 scenarios. One area: the attribution hook and its test. |

**Path:** light. A bug fix in one file plus its tests, with no new interface,
data or dependency.

## Acceptance criteria

```gherkin
Scenario: A value option before a gh pr create body takes its value
  Given a signed text, and signed.md that holds one
  When block-attribution.sh sees gh pr create with -Bnext --body, -Hfeat -b,
    -mSprint -F signed.md, -Rowner/rept -b, --base -t --body, --label -t -b,
    or --template -t -F signed.md, each before the signed text
  Then it exits 2
  And the block says "Blocked: the PR body carries Claude attribution."

Scenario: A value option before gh release create notes takes its value
  Given a signed text, and signed.txt that holds one
  When block-attribution.sh sees gh release create v2.4.1 with --target -t -n,
    --target -t -F signed.txt, --notes-start-tag -t -n,
    --discussion-category -t -n, --repo -t -n, or -Ro/rept -n,
    each before the signed text
  Then it exits 2
  And the block says "the release notes carry Claude attribution"

Scenario: Clean create commands with value options pass
  When block-attribution.sh sees
    gh pr create -B main -H feat -l bug -m Sprint -t 'feat(export): write ledger csv' -b 'Adds the ledger exporter.'
  Or gh release create v2.4.1 --target main --notes-start-tag v2.4.0 -t v2.4.1 -n 'clean notes'
  Then it exits 0
```

## Scope

**In:** the `gh pr create` and `gh release create` option tables in
`block-attribution.sh`; the tests that prove them.

**Out:**

- `gh release -R o/r create` passes a signed text by another cause: the
  release loop does not drop `-R` before the subcommand. See O3.
- `gh pr comment` and `gh pr review` bodies, as in `pr-edit-attribution` O1.
- Value options that a gh after 2.101.0 adds. Each one fails this way until it
  is listed.

## Technical plan

### Approach

The same change as `86a0c9f` made for `gh pr edit` and `gh pr merge`. `VALUE`
moves above the release table, so both create tables can use it. Each long
value option goes in a tuple, `RELEASE_VALUES` or `CREATE_VALUES`, spread into
the long table with `dict.fromkeys`. Each short value letter maps to `VALUE` in
the letter table. `emit` already drops a value whose kind is `None`
(`block-attribution.sh:42`), so a value option takes its value and emits
nothing. A boolean flag stays out of the tables: it takes no value.

The options come from `gh pr create --help` and `gh release create --help` on
gh 2.101.0, the `-R`/`--repo` inherited flag among them:

| Command | Short value options | Long value options |
| --- | --- | --- |
| `gh pr create` | `-a`, `-B`, `-H`, `-l`, `-m`, `-p`, `-r`, `-T`, `-R` | `--assignee`, `--attach`, `--base`, `--head`, `--label`, `--milestone`, `--project`, `--recover`, `--repo`, `--reviewer`, `--template` |
| `gh release create` | `-R` | `--discussion-category`, `--notes-start-tag`, `--repo`, `--target` |

Relies on: D20 (the hook reads PR bodies and titles from the command line
only), D54, and D58, drafted here.

### Changes

| File | Change | Why |
| --- | --- | --- |
| `plugins/zuko/scripts/block-attribution.sh:117` | `VALUE` and its comment move above the release table. The comment names the four help pages. | Scenarios 1, 2 |
| `plugins/zuko/scripts/block-attribution.sh:125` | `RELEASE_VALUES`, read at `:130-134` with `-R` as `VALUE`. | Scenario 2 |
| `plugins/zuko/scripts/block-attribution.sh:141` | `CREATE_VALUES`, read at `:172-178` with `-a`, `-B`, `-H`, `-l`, `-m`, `-p`, `-r`, `-T` and `-R` as `VALUE`. | Scenario 1 |
| `plugins/zuko/scripts/tests/test-block-attribution.sh:252` | Six release forms that block, and one clean form. | Scenarios 2, 3 |
| `plugins/zuko/scripts/tests/test-block-attribution.sh:365` | Seven `gh pr create` forms that block, and one clean form. | Scenarios 1, 3 |

### Non-functionals

| | |
| --- | --- |
| **Load** | Unchanged. A few more table entries for each create call. |
| **Breaks first** | A value option that a later gh adds is not listed, and hides a signed text the same way until it is. |
| **Security surface** | Closes `pr-edit-attribution` O4. The hook reads the same text and files as before. |
| **Proof it works** | `bash plugins/zuko/scripts/tests/run.sh block-attribution` gives 173 passed. |
| **Rollout** | No flag: a hook script. Rollback is `git revert 0a03192`. |

### Test plan

**E2E:** `bash plugins/zuko/scripts/tests/run.sh block-attribution` pipes each
command as a real hook payload into `block-attribution.sh`. The 13 forms that
block failed before the fix, 26 assertions in all (exit 0, and no block
message). All pass after it. The full suite, `bash plugins/zuko/scripts/tests/run.sh`,
gives 2428 passed, 0 failed.

### Decisions to record

Draft, for `DECISIONS.md` at ship:

```
## D58 · 2026-10-13 · The attribution hook gives each value option of gh pr create and gh release create its value

Why: a value option the create tables did not know left its value in the
walk, so -Bnext read as -t and --target -t took -n as the title. The signed
body or notes after it were never read (checked on v2.4.1, main 4ef85fe).
Rejected: listing only -B and --target, the two found cases (-Hfeat and
--label -t fail the same way), reading -T/--template as a body file (gh
2.101.0 refuses it with --body, and needs a prompt without one, O2).
Source: specs/gh-create-value-options.md
Status: active
```

## Review

2026-10-13 · 0 raw findings, 0 survived. Clean.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | The two found cases name only `-B` and `--target`. Each other value option of the two commands fails the same way, such as `-Hfeat` or `--label -t`. | flag | /debug | user | Decided alone | Chose: list every value-taking option of `gh pr create` and `gh release create`, short and long, from gh 2.101.0's help, as `86a0c9f` did for edit and merge. Other: list only `-B` and `--target`. Undo: git revert 0a03192. 2026-10-13 |
| O2 | `-T`/`--template` names a file of starting body text, and `--recover` names a file that holds a title and body. As value options, neither file is read. | flag | /debug | user | Decided alone | Chose: both take their value and emit nothing. On this machine gh 2.101.0 refuses `--template` with `--body` or `--body-file`, and `--recover` when not run from a terminal. Not checked: whether `--fill` with `--template` puts the template in the body. Other: read `-T` and `--template` as a body file, which can only over-block. Undo: map `T` and `--template` to `BODY_FILE` in the create table at `block-attribution.sh:174-178`. 2026-10-13 |
| O3 | `/debug` found a gap of another kind: `gh release -R o/r create v2.4.1 -n` with a signed text passes the hook on `main` and on this branch. The release loop at `block-attribution.sh:129` looks for `create` right after `release`, and does not drop `-R` first as `after_repo` does for `gh pr`. gh 2.101.0 reads that form as a create: `gh release -R o/r create --help` prints the create help. | flag | /debug | user | Decided alone | Chose: leave it out of this fix, whose cause is the option tables. Other: call `after_repo` in the release loop here. Undo: run /zuko:debug on it. 2026-10-13 |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **Signed text** — text that the ban pattern at `block-attribution.sh:203`
  matches: a line that credits Claude as an author of the work.
- **Value option** — an option that takes the next word, or the rest of its own
  token, as its value: `-B next`, `-Bnext`, `--base next`, `--base=next`.
- **Boolean flag** — an option that takes no value, such as `-d` (`--draft`).
- **The walk** — `read_options`, which reads a command's words left to right
  and hands each known option its value.
- **Positional** — a word on the command line that is not an option or an
  option's value, such as the tag `v2.4.1`.
- **Hook payload** — the JSON that Claude Code sends to a hook on stdin, with
  the Bash command in `tool_input.command`.
- **e2e** — end-to-end: one test that walks the whole slice.
