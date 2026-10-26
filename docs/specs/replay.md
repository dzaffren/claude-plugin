# Replay

**Version:** v1 · **Status:** Draft · **Type:** Feature · **Project type:** CLI/Library

**Shape doc:** docs/specs/living-board/shape.md
**Depends on:** idea-board

The idea board gets a Replay strip: one frame for each commit that changed the idea's shape or specs, oldest first. A frame shows the stage of each slice at that commit and what changed since the frame before, so the user can step through how the idea moved from shape to ship.

## Problem

The board shows an idea as it is now. It does not show how it got there: when a slice passed each pause, what changed between pauses, and in which order the slices moved. The facts are in git, but `main` hides most of them. In this repo, gate-card, pr-gate and library each reached `main` as one squash commit, so `main` shows each of them go from Not started to Shipped in one step. Even idea-board's first commit on `main` is already at Refined. The 12 commits that took gate-card through its pauses exist only on GitHub, in PR #104.

## Slice test

| Check                         | Result                                                                                                       |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Cuts every layer it needs     | Yes. `board.py` reads the history from git, `board.html` draws the strip, and each stage republishes as today |
| One e2e test walks it         | Yes. Render a fixture repo that has commits on `main`, a squash-merged PR and a branch in flight, then check the frames |
| Worth shipping alone          | Yes. The user can see when and how each slice moved, with no other slice shipped                             |
| Fits (≤5 scenarios, ≤2 areas) | Yes. 5 scenarios. Areas: the board builder and the board page                                                 |

**Path:** full. The slice adds a part to a published page and a new source of data, git history.

## User story

As the author of an idea, I want to step through the idea's history on its board, so that I can see when each slice moved and what changed at each step, without reading `git log`.

## Flow

```mermaid
flowchart LR
  ST["/spec, /build, /review, /ship"] -- "render, as today" --> BP[board.py]
  G[(git: main and the branch in flight)] -- commits that changed the shape or a slice spec --> BP
  PR[(GitHub: each squash-merged PR's commits)] -- the pause commits main lost --> BP
  BP -- "frames: stages + changes" --> PG[Board page: Replay strip]
  PG -- picks a frame --> U[User]
  U -- "sees: idea-board Refined → Built, and what changed" --> PG
```

Each stage renders the board as it does today. `board.py` now also reads the idea's commits from git, and the commits of each squash-merged PR from GitHub, and the board draws one frame for each commit. The user picks a frame to see the stage of each slice at that commit and what changed.

## Acceptance criteria

```gherkin
Scenario: the board replays the idea's commits, oldest first
  Given docs/specs/living-board/shape.md and its slice specs were changed in 11 commits on main, from 7ac7353 at 2026-10-26 00:28 to 2f594f4 at 15:06
  When /spec replay republishes the board at pause 1
  Then the board has a Replay strip, and its first frame is 7ac7353 "docs(spec): add living-board shape and idea-board spec"
  And each frame shows its date and time, its short hash, its commit subject and the stage of each of the 5 slices at that commit
  And the frame for 2f594f4 shows idea-board, gate-card, pr-gate and library at Shipped, and replay at Not started

Scenario: a frame shows what moved since the frame before
  Given the Replay strip of living-board
  When the user picks the frame 16c53ad "docs(spec): mark idea-board built"
  Then the frame reads "idea-board: Refined → Built"
  And it lists the changes to docs/specs/idea-board.md since the frame before, a5cb93f, with the gate card's tags: added, removed, changed, new row, resolved
  And the stage rail shows each slice as it was at 16c53ad

Scenario: a squash-merged slice shows the commits of its PR
  Given gate-card reached main as the one commit caf25a7, squash-merged from PR #104
  And PR #104 has 12 commits that changed docs/specs/gate-card.md, from b845774 "docs(spec): draft gate-card pause 1" at 09:59 to e25a7c8 at 10:56
  When the board is rendered
  Then the strip shows those 12 frames in place of caf25a7
  And gate-card moves through Pause 1 at b845774, Pause 2 at d6e6794, Refined at 2887111, Built at 1059896 and Shipped at 2f69a9c

Scenario: GitHub cannot be reached
  Given the network is down
  When the board is rendered
  Then gate-card, pr-gate and library each show as one frame, their squash commit on main
  And the strip reads "PR commits not read: <reason>. Squash-merged slices show as one step."
  And the rest of the board draws as usual

Scenario: an idea with no commits yet
  Given /shape has just written docs/specs/ask-up-front/shape.md, and nothing under it is committed
  When /shape renders the board
  Then the Replay strip reads "No commits yet for this idea. Replay starts after the first commit."
  And the rest of the board draws as usual
```

Scenarios 3 and 4 follow the recommended answer to O1. Another answer changes them.

## Scope

**In:**

- A Replay strip on the idea board, with one frame for each commit that changed the shape or a slice spec.
- The commits of the branch in flight, after the commits of `main`. The current slice then shows a frame for each pause commit.
- For each squash-merged slice, the commits of its PR, in place of its squash commit.
- In each frame: the date and time, the short hash, the subject, the stage of each slice, and what changed since the frame before.
- Picking a frame sets the stage rail to that frame.

**Out:**

- Changes that were never committed. The live board already shows the work tree as it is now.
- Changes to `DECISIONS.md` alone. A D-entry is recorded in the same PR as its spec, so its frame is already in the strip.
- Ideas with no shape. They have no board (shape O8, settled in library).
- Playing the frames as an animation. Not in any slice. The user steps one frame at a time.
- History from a GitLab origin or a repo with no GitHub remote. Its squash-merged slices show as one step, as in scenario 4. Not in any slice.

## Open items

| ID  | What | Type | Raised at | Owner | Status | Answer |
| --- | ---- | ---- | --------- | ----- | ------ | ------ |
| O1  | Replay rebuilds frames from git history, but a spec is often written in one commit, so it may have only one or two frames. On `main`, gate-card, pr-gate and library are one squash commit each. Where do the lost frames come from? (from shape O9) | question | shape | user | Open | — |
| O2  | What does a frame show: the stage of each slice and what changed, or the whole board as it was at that commit, with its diagrams and panels? | question | spec p1 | user | Open | — |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **Frame** — one step of the Replay strip: the idea as it was at one commit.
- **Squash merge** — merging a PR as one new commit on `main`. The PR's own commits stay on GitHub, but not on `main`.
- **Branch in flight** — the branch of the slice that is being worked on now and is not merged.
- **e2e** — end-to-end: one test that walks the whole slice as a user would.
