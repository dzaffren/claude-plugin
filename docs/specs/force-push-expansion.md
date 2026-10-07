# Force push expansion

**Version:** v1 · **Status:** Shipped · **Type:** Bug · **Project type:** CLI/Library

**Depends on:** `hook-command-match` — the parsed git arguments this check reads

The force-push guard blocks every spelling git 2.52.0 forced a remote with, not
only `--force` and a lone `-f`, and blocks a push whose brace or glob the shell
could expand into one. Found after `release-commit-brace`; fixed through `/debug`.

## Problem

`block-dangerous.sh` matched `--force…` and a lone `-f` in the git arguments
`git-command.py` prints. Each spelling below was fed to the hook and pushed to a
scratch bare remote whose `main` was behind, on 2026-10-07:

| Push arguments                    | git 2.52.0       | Hook before |
| --------------------------------- | ---------------- | ----------- |
| `origin +main`, `origin +HEAD:main` | forced          | allowed     |
| `-uf origin main`, `-fu origin main` | forced         | allowed     |
| `--mirror origin`, `--mi origin`  | forced           | allowed     |
| `{--force,origin} main`           | bash passes `--force origin main` | allowed |
| `origin --forc main`              | refused: ambiguous | allowed   |

```
git push origin +main            git push {--force,origin} main
        │                                │
        ▼                                ▼
git-command.py: push origin +main        push {--force,origin} main
        │                                │
        ▼                                ▼
push_re: --force* | -f ── no match ──► exit 0, allowed
        │                                │
        ▼                                ▼
git: + forces that ref           bash expands: git push --force origin main
```

## Slice test

| Check                         | Result                                                              |
| ----------------------------- | ------------------------------------------------------------------- |
| Cuts every layer it needs     | yes — the one hook script and its test                              |
| One e2e test walks it         | yes — `test-block-dangerous.sh` feeds each command to the real hook |
| Worth shipping alone          | yes — the guard blocks the force pushes it missed                   |
| Fits (≤5 scenarios, ≤2 areas) | yes — 4 scenarios, 1 area (hook and gate scripts)                   |

**Path:** light — a bug fix in one script plus its test, with no new
interface, data or dependency.

## Acceptance criteria

```gherkin
Scenario: every spelling git forces with is blocked
  When the hook sees git push origin +main, git push -uf origin main, or git push --mi origin
  Then it exits 2 and says a force push rewrites shared history

Scenario: a brace or glob in a push is blocked
  When the hook sees git push {--force,origin} main, or git push origin feat/*
  Then it exits 2 and the reason names a brace or glob

Scenario: a command that will not parse is judged on its raw text
  Given a push followed by a heredoc that is never closed
  When the push is origin +main, origin '+main', -uf, --mi, or a brace
  Then it exits 2

Scenario: ordinary pushes pass
  When the hook sees git push -u origin feat/thing, git push -uv origin feat/thing,
    git push --atomic origin main v2.3.0, git push --follow-tags origin main, or git push origin main
  Then it exits 0
```

## Scope

**In:** the force and brace/glob regexes in the parsed and the raw-text paths;
the tests that prove them.

**Out:** known limits, recorded in D34. Each passes the hook on main too.

- A force flag or `+` refspec built by a variable, `$(...)`, a backtick or
  `$'...'`, such as `F=--force; git push $F origin main`.
- In a command that will not parse, a spelling split by a backslash or quotes,
  such as `origin ""+main`.
- Force set through git config: `git -c remote.origin.mirror=true push origin`,
  or a `+` push refspec already saved in config.
- Pushes that delete rather than force: `--delete`, `-d`, `origin :main`,
  `--prune`.

## Technical plan

### Approach

Name the four spellings in `push_re`: `--force…`, `--m…` (only `--mirror`
starts with `m`, so git takes any prefix), a short-option word holding `f`, and
a word starting with `+`. A second regex, `expand_re`, blocks a push with a
`{`, `}`, `[`, `]`, `*` or `?`, with its own reason. The raw-text fallback gets
both, with an optional quote before the flag.

Relies on: D31 (the hook fails closed on a payload it cannot read). Records D34.

### Changes

| File                                                 | What changes                                                                    | Why            |
| ---------------------------------------------------- | ------------------------------------------------------------------------------- | -------------- |
| `plugins/zuko/scripts/block-dangerous.sh:16`         | `push_re` names four spellings, `expand_re` is new, in both paths; a comment lists them | scenarios 1–3 |
| `plugins/zuko/scripts/tests/test-block-dangerous.sh` | blocked forms, brace and glob forms, unparsed forms, and allowed pushes         | scenarios 1–4  |

### Non-functionals

|                      |                                                                                                            |
| -------------------- | ---------------------------------------------------------------------------------------------------------- |
| **Load**             | one more `grep -E` per Bash call                                                                           |
| **Breaks first**     | a push with a brace or glob, quoted or not, such as `git push origin 'refs/heads/*'`; a `-o` value holding `f` |
| **Security surface** | closes force pushes spelled `+ref`, `-uf`, `--mirror` and by brace expansion                               |
| **Proof it works**   | `bash plugins/zuko/scripts/tests/run.sh block-dangerous` gives 86 passed                                   |
| **Rollout**          | no flag: a hook script. Rollback is `git revert` of the fix commit                                         |

### Test plan

**E2E:** `bash plugins/zuko/scripts/tests/run.sh block-dangerous` pipes each
command as a real hook payload into `block-dangerous.sh`. Before the fix the 12
new block cases failed with exit 0. `/review` found the raw-text fallback
untested: cut back to `--force|\+` it still passed, so the unparsed loop was
added, and its 4 new cases fail against that cut-down version. Every `git push`
in the skills and docs gives the same verdict as before. The full suite gives
2018 passed, 0 failed.

### Decisions to record

Recorded as D34.

## Open items

| ID  | What                                                                                     | Type     | Raised at | Owner | Status   | Answer                                                                                  |
| --- | ---------------------------------------------------------------------------------------- | -------- | --------- | ----- | -------- | --------------------------------------------------------------------------------------- |
| O1  | Review found three older gaps: shell variables, escaped spellings unparsed, git `-c` config | question | /review   | user  | Resolved | Left as known limits and recorded in D34; each passes on main too (2026-10-07)          |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **e2e** — end-to-end: one test that walks the whole slice as a user would
- **Glob** — `*`, `?` or `[...]`, which bash replaces with matching file names
- **Refspec** — the `source:destination` part of a push; a leading `+` makes git
  overwrite that one branch even when it is not a fast-forward
- **Mirror push** — makes the remote match every local ref, overwriting and
  deleting as needed
