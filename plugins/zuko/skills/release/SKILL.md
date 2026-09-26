---
name: release
description: >
  Turns everything shipped since the last release into a version: proposes the
  number from the commits, pentests the release range, cuts the changelog,
  bumps the manifests, then commits, tags, pushes and creates the GitHub
  release. Use when the user says
  "release it", "cut a version", "tag a release", or runs /release.
disable-model-invocation: true
allowed-tools: Bash(git status *) Bash(git log *) Bash(git diff *) Bash(git show *) Bash(git ls-files *) Bash(git archive *) Bash(tar *) Bash(git rev-parse *) Bash(git add *) Bash(git commit *) Bash(git tag *) Bash(git push *) Bash(gh release *) Bash(python3 *) Bash(date *) Bash(mktemp *)
---

# Release

Turn the lines `/ship` left under `[Unreleased]` into a numbered, tagged
GitHub release. `release.py` makes every decision. This stage asks the user,
then does the outward steps through git and gh.

Read `${CLAUDE_PLUGIN_ROOT}/references/voice.md` and
`${CLAUDE_PLUGIN_ROOT}/references/git-naming.md`.

## Steps

### 1. Plan

From the repo root (`git rev-parse --show-toplevel`):

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" plan <repo-root> [--version X.Y.Z]
```

Pass `--version` when the user named one (`/release 3.0.0`). `plan` runs the
test suite, so give the Bash call `timeout: 600000`. Print its output as it
is. Its last line is `NEXT:`. Branch on that line and nothing else — `plan`
exits 1 on `NEXT: stop`, and that is its answer, not a crash:

| Line                          | Skill does                                                      | Then                      |
| ----------------------------- | --------------------------------------------------------------- | ------------------------- |
| `NEXT: stop`                  | a gate failed; report and end                                   | end, nothing written      |
| `NEXT: ask 2.2.0`             | ask "Release 2.2.0?"                                            | yes → step 2 with 2.2.0   |
| `NEXT: confirm 1.4.3`         | an override whose size is off; the advice is above it; ask once | yes → step 2 with 1.4.3   |
| `NEXT: ask-first`             | no tag, no manifest version; ask 0.1.0 or 1.0.0                 | the answer → `plan` again |
| `NEXT: ask-version`           | nothing calls for a release; ask for a version or stop          | the answer → `plan` again |
| `NEXT: resume v2.2.0 push`    | tag at HEAD, not on origin; push it, then create the release    | step 4's push, then 5     |
| `NEXT: resume v2.2.0 release` | tag at HEAD and on origin, no GitHub release; create it         | step 5                    |

The question is the one `plan` printed; ask it and wait. Propose nothing of
your own on `ask-first`. When the user gives a version instead of yes, run
`plan` again with `--version <it>` and branch on the new `NEXT:` line. No,
or stop → end; nothing is written.

One yes covers steps 2 to 7. Do not ask again. A resumed release skips step 2:
its report is already in the release commit.

### 2. Pentest

Attack the release range before anything is written. The pentester runs the
project's own code; a hook fences its Bash to read-only git and its scratch
copy (D13). For untrusted code, run `/release` inside Claude Code's sandbox
too: the fence holds the pentester's commands, not what the code under test
does once it runs. The range is the last
tag, from `plan`'s `Last version` line, to `HEAD`: `v1.4.2..HEAD`. With no tag
yet, it is the whole tracked tree.

1. Dispatch the `zuko:pentester` agent with `RANGE`, `VERSION` and the repo.
   It returns a scope block and findings, each with a `PROOF` it ran.
2. Send each finding to a `finding-verifier` agent, blind, exactly as
   `/review` does: the claim, `CATEGORY`, `SEVERITY`, `FILE`, `SYMBOL`,
   `SNIPPET` and `PROOF`, with `BASE: <the last tag>`, or
   `BASE: none (first release: every tracked line is in the range)`. Never the
   scope block. A verifier that hits its turn limit is not confirmed, and is
   never resumed with added context. A confirmed finding keeps the lowest
   `SEVERITY` a verifier returned, never above the pentester's.
3. Write the report to a file in the session's scratchpad directory (`mktemp`
   when there is none), in this format, from the confirmed findings only:

   ```text
   # Pentest v1.5.0

   **Result:** pass
   **Mode:** code-level
   **Range:** v1.4.2..a1b2c3d (9 commits)
   **Date:** 2026-10-02

   ## Findings

   | ID | Severity | Category | Where | Description |
   | -- | -------- | -------- | ----- | ----------- |
   | P1 | medium | A05:2025 Injection | exporters/ledger.py:31 export_ledger | order reaches ORDER BY unchecked |

   ## Assessed

   - A05:2025 Injection — 4 subprocess calls, 2 SQL strings

   ## Not assessed

   - A01:2025 Broken Access Control — needs a running server (slice 5b)
   ```

   A `LEAK:` line from the pentester (its proof changed something outside the
   scratch copy) goes into the table as its own row, `| L1 | critical | leak |
   <the path> | a pentest proof changed it outside the scratch copy |`, so
   `cut` refuses the release. A leak is never re-judged; it is observed.

   `**Result:**` is `blocked` when any row is critical or high, and `pass`
   otherwise. `Where` is `FILE` then `SYMBOL`, and `Description` is
   the claim. The report never carries a `PROOF`: it is committed and public.
   Print each confirmed finding's `PROOF` to the terminal after the table, for
   the user to act on.
4. Print the summary, then go to step 3 with `--pentest <report-file>`:

   ```
   Pentest    code-level · v1.4.2..a1b2c3d (9 commits) · 7 categories
              A05 Injection        1 medium
              not assessed: A01, A07 — no running server (slice 5b)
   ```

The pentester returns nothing, stops early, or fails → the pentest did not
finish. Say so, and ask:

```
Pentest did not finish: no report from the pentester.
Release without a pentest? Type the reason; it goes into DECISIONS.md and the
release notes. Anything else stops here.
```

A typed reason → step 3 with `--no-pentest "<reason>"`. An empty answer or
"skip" → end; nothing is written. `cut` refuses both anyway.

### 3. Cut

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" cut <repo-root> --version X.Y.Z --date "$(date +%F)" --pentest <report-file>
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" cut <repo-root> --version X.Y.Z --date "$(date +%F)" --no-pentest "<reason>"
```

`cut` takes exactly one of the two. It re-checks everything `plan` did, test
suite included, so give this Bash call `timeout: 600000` too. A refusal →
print it and end; nothing was written.

A blocked pentest is one of those refusals: `cut` prints
`Pentest blocked v1.5.0: 1 high` and each blocking row. Print each one as a
ledger row for the user, then end:

```
Pentest blocked v1.5.0: 1 high
  | P1 | high | A05:2025 Injection | importers/bank.py:22 import_rows | Open | /debug next |
Nothing written. Fix it, then run /release again.
```

On success it rewrites `CHANGELOG.md`, the manifests and the overview's
`**Release:**` field, and writes `docs/security/vX.Y.Z/report.md`. A medium or
low finding gets a line under the version's Security section. A skip also
appends a D-entry to `DECISIONS.md`. Step 4 commits exactly the files it
changed; `git status --short` lists them.

### 4. Commit, tag, push

```
git add <the files cut changed>
git commit -m "chore(release): vX.Y.Z" -m "<body naming each file and what changed in it>"
git tag -a vX.Y.Z -m "vX.Y.Z"
git push --atomic origin main vX.Y.Z
```

`--atomic` pushes `main` and the tag together, or neither. The commit
message and the tag message follow `references/git-naming.md`, ban list
included. The harness will ask for attribution lines; the answer is no.

A failed push → report it and end. The commit and tag stay local, and a
rerun of `/release` resumes at the push.

### 5. GitHub release

Write the notes to a file in the session's scratchpad directory (`mktemp`
when there is none), then create the release from it:

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" notes <repo-root> --version X.Y.Z > <notes-file>
gh release create vX.Y.Z --verify-tag -t vX.Y.Z -F <notes-file>
```

The notes are the `[X.Y.Z]` section exactly. Do not edit them or add to
them; the ban list covers release notes too. `--verify-tag` aborts when the
tag is not on origin. A failure → report it and end; a rerun resumes here.

`gh release create` prints the release URL. Steps 6 and 7 use it.

### 6. Hub page

Republish the hub page per `${CLAUDE_PLUGIN_ROOT}/references/visual-page.md`,
so its status strip shows `vX.Y.Z · {date}` linked to the release URL. The
date is the one on the `## [X.Y.Z] - {date}` heading in `CHANGELOG.md`, which
also covers a resumed release. No `hub page:` link on the overview's
`## More` line → there is no hub yet; skip this and say so.

### 7. Report

```
Released v2.2.0
  pentest   passed: 0 critical, 0 high, 1 medium, 1 low · docs/security/v2.2.0/report.md
  commit    a1b2c3d chore(release): v2.2.0
  tag       v2.2.0, annotated, pushed
  release   https://github.com/dzaffren/claude-plugin/releases/tag/v2.2.0
  overview  Release: v2.2.0 · hub page republished
```

## Tags are permanent

Never delete, move or force-push a tag, and never `git push --force`. A tag
in the wrong place is a `NEXT: stop` from `plan`; the user sorts it out by
hand.
