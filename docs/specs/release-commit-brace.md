# Release commit brace

**Version:** v1 · **Status:** Built · **Type:** Bug · **Project type:** CLI/Library

**Depends on:** `release-commit-guard` — this narrows the check that slice added

The release-commit check refuses an unquoted brace or glob, which bash expands
into extra git arguments after the check has passed. Found by the v2.3.0
pentest (P1); fixed through `/debug`.

## Problem

`block-dangerous.sh` lets one commit onto main: the release commit `cut`
prepared (D30). `whole_call` in `release-commit.py` decides the call is a plain
`git commit -m <msg> [-m <msg> ...]` by counting `shlex` tokens. `shlex` removes
quotes but does not expand braces or globs, and the check refused only `$`, a
backtick and `();<>|&`. So an unquoted `{A,B}`, `*`, `?` or `[` passed as one
token, and bash turned it into several words before git ran. Each row was run
against `release-commit.py` on 2026-10-07, in a scratch repo on main with a
matching marker and a modified tracked file `notes.txt`:

| Command                                                          | Exit before | What git receives                                  |
| ---------------------------------------------------------------- | ----------- | -------------------------------------------------- |
| `git commit -m "chore(release): v2.3.0" -m {Body,--all}`         | 0           | `-m Body --all`: every modified tracked file       |
| `git commit -m "chore(release): v2.3.0" -m {Body,notes.txt}`     | 0           | `-m Body notes.txt`: a pathspec, committed as on disk |
| `git commit -m "chore(release): v2.3.0" -m *`                    | 0           | `-m` plus every file name in the directory         |

```
Bash call ── block-dangerous.sh:47 ──► release-commit.py whole_call
                                         shlex: -m  {Body,--all}   (one token)
                                         │ exit 0, allowed
                                         ▼
               bash expands braces ──► git commit ... -m Body --all
                                         ▼
                         every modified tracked file lands on main
```

## Slice test

| Check                         | Result                                                              |
| ----------------------------- | ------------------------------------------------------------------- |
| Cuts every layer it needs     | yes — the one check script and the hook's test                      |
| One e2e test walks it         | yes — `test-block-dangerous.sh` feeds each command to the real hook |
| Worth shipping alone          | yes — the release exception can no longer commit extra files        |
| Fits (≤5 scenarios, ≤2 areas) | yes — 2 scenarios, 1 area (hook and gate scripts)                   |

**Path:** light — a bug fix in one function plus its tests, with no new
interface, data or dependency.

## Acceptance criteria

```gherkin
Scenario: an unquoted brace or glob is refused
  Given a repo on main whose marker and staged files match the v2.3.0 release
  When the hook sees git commit -m "chore(release): v2.3.0" -m {Body,--all}
  Or -m *, or -m body?, or -m [a-z]*
  Then it exits 2

Scenario: the same characters inside quotes are text
  Given the same repo
  When the hook sees git commit -m "chore(release): v2.3.0" -m "CHANGELOG.md: [Unreleased] under [2.3.0], {A,B} and * quoted."
  Then it exits 0
```

## Scope

**In:** `whole_call`'s refused characters; the tests that prove it.

**Out:**

- The force-push check in `block-dangerous.sh` has the same class of gap:
  `git push {--force,origin} main` exits 0, and so does `git push origin +main`.
  Raised to the user on 2026-10-07; not fixed here.
- An unquoted `~` is still allowed: it changes one word's text, never the
  number of words.

## Technical plan

### Approach

Pass `punctuation_chars="();<>|&{}[]*?"` to `shlex` in `whole_call`, in place of
`True` (which means `();<>|&`). Unquoted, those characters come out as tokens of
their own, and the existing punctuation check refuses them. Quoted or
backslash-escaped, they stay inside the word, where bash does not expand them
either.

Relies on: D30. Records D33.

### Changes

| File                                                 | What changes                                                                         | Why         |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------ | ----------- |
| `plugins/zuko/scripts/lib/release-commit.py:59`      | brace and glob characters join `shlex`'s punctuation; docstrings say why             | scenario 1  |
| `plugins/zuko/scripts/tests/test-block-dangerous.sh` | four refused forms in the release loop, one quoted form that passes                  | scenarios 1, 2 |
| `plugins/zuko/scripts/tests/test-release.sh:718`     | `changed()` sorts with `LC_ALL=C`; under `en_US.utf8` three tests failed before any change | a red baseline |

### Non-functionals

|                      |                                                                                                   |
| -------------------- | ------------------------------------------------------------------------------------------------- |
| **Load**             | unchanged; one tokenise per commit on main                                                        |
| **Breaks first**     | a message made only of these characters, such as `-m "*"`, is refused though bash would pass it   |
| **Security surface** | closes pentest P1: the release exception commits only the staged files `cut` wrote                |
| **Proof it works**   | `bash plugins/zuko/scripts/tests/run.sh block-dangerous` gives 65 passed                          |
| **Rollout**          | no flag: a hook script. Rollback is `git revert` of the fix commit                                |

### Test plan

**E2E:** `bash plugins/zuko/scripts/tests/run.sh block-dangerous` pipes each
command as a real hook payload into `block-dangerous.sh`. The four refused forms
failed against the old `release-commit.py` (exit 0) and pass after the fix. The
full suite gives 1997 passed, 0 failed. `/review` found nothing, after probing
escaped spaces, empty quotes, `~`, extglob and tabs against what bash passes git.

### Decisions to record

Recorded as D33.

## Open items

| ID  | What                                                    | Type     | Raised at | Owner  | Status   | Answer                                                                                     |
| --- | ------------------------------------------------------- | -------- | --------- | ------ | -------- | ------------------------------------------------------------------------------------------ |
| O1  | Does any legitimate release commit now get refused?     | question | /debug    | claude | Resolved | No: the v2.3.0 commit's own message passes, `[2.3.0]` in quotes included (2026-10-07)      |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **e2e** — end-to-end: one test that walks the whole slice as a user would
- **Pentest** — the security test `/release` runs on the code it ships; its
  findings are numbered P1, P2, …
- **Glob** — `*`, `?` or `[...]`, which bash replaces with matching file names
- **Pathspec** — file names after `git commit`; git commits those files as they
  are on disk, not as staged
