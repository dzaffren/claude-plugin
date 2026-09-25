---
name: release
description: >
  Turns everything shipped since the last release into a version: proposes the
  number from the commits, cuts the changelog, bumps the manifests, then
  commits, tags, pushes and creates the GitHub release. Use when the user says
  "release it", "cut a version", "tag a release", or runs /release.
disable-model-invocation: true
allowed-tools: Bash(git status *) Bash(git log *) Bash(git rev-parse *) Bash(git add *) Bash(git commit *) Bash(git tag *) Bash(git push *) Bash(gh release *) Bash(python3 *) Bash(date *)
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
is. Its last line is `NEXT:`. Branch on that line and nothing else:

| Line                          | Skill does                                                      | Then                      |
| ----------------------------- | --------------------------------------------------------------- | ------------------------- |
| `NEXT: stop`                  | a gate failed; report and end                                   | end, nothing written      |
| `NEXT: ask 2.2.0`             | ask "Release 2.2.0?"                                            | yes → step 2 with 2.2.0   |
| `NEXT: confirm 1.4.3`         | an override whose size is off; the advice is above it; ask once | yes → step 2 with 1.4.3   |
| `NEXT: ask-first`             | no tag, no manifest version; ask 0.1.0 or 1.0.0                 | the answer → `plan` again |
| `NEXT: ask-version`           | nothing calls for a release; ask for a version or stop          | the answer → `plan` again |
| `NEXT: resume v2.2.0 push`    | tag at HEAD, not on origin; push it, then create the release    | step 3's push, then 4     |
| `NEXT: resume v2.2.0 release` | tag at HEAD and on origin, no GitHub release; create it         | step 4                    |

The question is the one `plan` printed; ask it and wait. Propose nothing of
your own on `ask-first`. When the user gives a version instead of yes, run
`plan` again with `--version <it>` and branch on the new `NEXT:` line. No,
or stop → end; nothing is written.

One yes covers steps 2 to 6. Do not ask again.

### 2. Cut

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" cut <repo-root> --version X.Y.Z --date "$(date +%F)"
```

`cut` re-checks everything `plan` did. A refusal → print it and end; nothing
was written. On success it rewrites `CHANGELOG.md`, the manifests and the
overview's `**Release:**` field. Step 3 commits exactly the files it changed;
`git status --short` lists them.

### 3. Commit, tag, push

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

### 4. GitHub release

Write the notes to a file in the session's scratchpad directory (`mktemp`
when there is none), then create the release from it:

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" notes <repo-root> --version X.Y.Z > <notes-file>
gh release create vX.Y.Z --verify-tag -t vX.Y.Z -F <notes-file>
```

The notes are the `[X.Y.Z]` section exactly. Do not edit them or add to
them; the ban list covers release notes too. `--verify-tag` aborts when the
tag is not on origin. A failure → report it and end; a rerun resumes here.

`gh release create` prints the release URL. Steps 5 and 6 use it.

### 5. Hub page

Republish the hub page per `${CLAUDE_PLUGIN_ROOT}/references/visual-page.md`,
so its status strip shows `vX.Y.Z · {date}` linked to the release URL. The
date is the one on the `## [X.Y.Z] - {date}` heading in `CHANGELOG.md`, which
also covers a resumed release. No `hub page:` link on the overview's
`## More` line → there is no hub yet; skip this and say so.

### 6. Report

```
Released v2.2.0
  commit    a1b2c3d chore(release): v2.2.0
  tag       v2.2.0, annotated, pushed
  release   https://github.com/dzaffren/claude-plugin/releases/tag/v2.2.0
  overview  Release: v2.2.0 · hub page republished
```

## Tags are permanent

Never delete, move or force-push a tag, and never `git push --force`. A tag
in the wrong place is a `NEXT: stop` from `plan`; the user sorts it out by
hand.
