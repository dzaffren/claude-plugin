# Replay

**Version:** v1 · **Status:** Refined · **Type:** Feature · **Project type:** CLI/Library

**Shape doc:** docs/specs/living-board/shape.md
**Depends on:** idea-board

The idea board gets a Replay strip: one step for each commit that changed the idea's shape or specs, oldest first. A step shows the stage of each slice at that commit and what changed since the step before, so the user can step through how the idea moved from shape to ship.

## Problem

The board shows an idea as it is now. It does not show how it got there: when a slice passed each pause, what changed between pauses, and in which order the slices moved. The facts are in git, but `main` hides most of them. In this repo, gate-card, pr-gate and library each reached `main` as one squash commit, so `main` shows each of them go from Not started to Shipped in one step. Even idea-board's first commit on `main` is already at Refined. The 12 commits that took gate-card through its pauses exist only on GitHub, in PR #104.

## Slice test

| Check                         | Result                                                                                                       |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Cuts every layer it needs     | Yes. `board.py` reads the history from git, `board.html` draws the strip, and each stage republishes as today |
| One e2e test walks it         | Yes. Render a fixture repo that has commits on `main`, a squash-merged PR and a branch in flight, then check the steps |
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
  BP -- "steps: stages + changes" --> PG[Board page: Replay strip]
  PG -- picks a step --> U[User]
  U -- "sees: idea-board Refined → Built, and what changed" --> PG
```

Each stage renders the board as it does today. `board.py` now also reads the idea's commits from git, and the commits of each squash-merged PR from GitHub, and the board draws one step for each commit. The user picks a step to see the stage of each slice at that commit and what changed.

## Acceptance criteria

```gherkin
Scenario: the board replays the idea's commits, oldest first
  Given docs/specs/living-board/shape.md and its slice specs were changed in 11 commits on main, from 7ac7353 at 2026-10-26 00:28 to 2f594f4 at 15:06
  When /spec replay republishes the board at pause 1
  Then the board has a Replay strip, and its first step is 7ac7353 "docs(spec): add living-board shape and idea-board spec"
  And each step shows its date and time, its short hash, its commit subject and the stage of each of the 5 slices at that commit
  And the step for 2f594f4 shows idea-board, gate-card, pr-gate and library at Shipped, and replay at Not started

Scenario: a step shows what moved since the step before
  Given the Replay strip of living-board
  When the user picks the step 16c53ad "docs(spec): mark idea-board built"
  Then the step reads "idea-board: Refined → Built"
  And it lists the changes to docs/specs/idea-board.md since the step before, a5cb93f, with the gate card's tags: added, removed, changed, new row, resolved
  And the step shows the stage of each of the 5 slices at 16c53ad

Scenario: a squash-merged slice shows the commits of its PR
  Given gate-card reached main as the one commit caf25a7, squash-merged from PR #104
  And PR #104 has 12 commits that changed docs/specs/gate-card.md, from b845774 "docs(spec): draft gate-card pause 1" at 09:59 to e25a7c8 at 10:56
  When the board is rendered
  Then the strip shows those 12 steps in place of caf25a7
  And gate-card moves through Pause 1 at b845774, Pause 2 at d6e6794, Refined at 2887111, Built at 1059896 and Shipped at 2f69a9c

Scenario: GitHub cannot be reached
  Given the network is down
  When the board is rendered
  Then gate-card, pr-gate and library each show as one step, their squash commit on main
  And the strip reads "PR commits not read: <reason>. Squash-merged slices show as one step."
  And the rest of the board draws as usual

Scenario: an idea with no commits yet
  Given /shape has just written docs/specs/ask-up-front/shape.md, and nothing under it is committed
  When /shape renders the board
  Then the Replay strip reads "No commits yet for this idea. Replay starts after the first commit."
  And the rest of the board draws as usual
```

## Scope

**In:**

- A Replay strip on the idea board, with one step for each commit that changed the shape or a slice spec.
- The commits of the branch in flight, after the commits of `main`. The current slice then shows a step for each pause commit.
- For each squash-merged slice, the commits of its PR, in place of its squash commit.
- In each step: the date and time, the short hash, the subject, the stage of each slice, and what changed since the step before.
- The board opens on the last step. A step changes only the Replay strip; the rest of the board stays as it is now.

**Out:**

- Changes that were never committed. The live board already shows the work tree as it is now.
- Changes to `DECISIONS.md` alone. A D-entry is recorded in the same PR as its spec, so its step is already in the strip.
- Ideas with no shape. They have no board (shape O8, settled in library).
- Playing the steps as an animation. Not in any slice. The user goes one step at a time, or drags the slider.
- History from a GitLab origin or a repo with no GitHub remote. Its squash-merged slices show as one step, as in scenario 4. Not in any slice.

## Interface

**Preview:** https://claude.ai/artifact/2mvUGzveMZJ1rr2T4SiUL9. It is built from the real `living-board` board, with steps read from `main`, PRs #104 to #106 and this branch. Its buttons show the three states: GitHub read, GitHub not reached, and no commits yet. A fourth button jumps to 16c53ad. The buttons exist only in the preview.

```mermaid
flowchart TB
  F["Slices filmstrip and slice map, as before"] --> RP["Replay: heading, step count, source"]
  RP --> N["Note, only when GitHub was not read"]
  RP --> B["Bar: back, slider, forward, step i of n"]
  B --> T["Ticks: one per step, amber where a slice moved"]
  B -- picks --> S["Step card"]
  S --> H["Head: date and time, hash, PR, subject"]
  S --> M["Moved: slice from → to, and each slice's stage"]
  S --> C["Changed since the step before: file, then tagged items"]
```

The Replay strip sits at the foot of the board, under the slice map. The bar picks a step, and the card under it shows that step. The rest of the board does not change.

**The strip**

| Part | What it shows | From |
| --- | --- | --- |
| Heading | `Replay · step through the idea's commits`, and on the right `<n> steps · from main, the merged PRs and this branch`. When GitHub was not read: `from main and this branch` | — |
| Note | `PR commits not read: <reason>. Squash-merged slices show as one step.`, in amber, under the heading. Only when GitHub was not read | The failed `git fetch` |
| Bar | `◀`, a slider with one stop per step, `▶`, then `step <i> of <n>`. The slider takes the arrow keys. `◀` is off at step 1, and `▶` is off at the last step | — |
| Ticks | One mark per step under the slider. A mark is amber when a slice changed stage at that step. The current step has an outline | Each step's Moved list |
| Head | `<YYYY-MM-DD HH:MM> · <short hash>`, then ` · from PR #<n>` for a step read from a PR, then the commit subject | The commit |
| Moved | One line per slice that changed stage: `<slice>: <stage> → <stage>`. With none: `No slice changed stage.` Then a chip per slice, `<slice> · <stage>`, in the board's stage colours. A slice that moved has a ring | Each slice spec at that commit, read with the board's stage rule |
| Changed | `Changed since step <i-1>`. Then each file that changed: its path, then one line per change with a gate card tag: `added`, `removed`, `changed`, `new row`, `resolved` or `accepted risk`. A spec seen for the first time is `added · the spec`. A file whose only change is above its first `##` heading: `Only the Status line changed.` | The file at this commit against the step before, compared as the gate card compares |

The board opens on the last step. With no commit for the idea, the strip has only its heading and `No commits yet for this idea. Replay starts after the first commit.`

**Which commits are steps**

1. Each commit on `main` that changed the shape or a slice spec, oldest first. The commits of a merged branch count, when the merge was a merge commit.
2. A squash commit of a merged PR is replaced by the commits of that PR that changed those files, in their order.
3. Then each commit of the branch in flight, after its base on `main`.

For `living-board` today, that gives 38 steps: 8 from `main` for idea-board, 12 from PR #104, 8 from PR #105, 8 from PR #106, and 2 from `feat/replay`. Their JSON is 15 KB. With GitHub not reached, it gives 13 steps.

## Technical plan

### Approach

`board()` gains a `replay` key, built by a new `replay()` in `board.py`. It lists the idea's commits with `git rev-list`, swaps each squash commit for its PR's commits, and reads every file at every step through one `git cat-file --batch` process. Each step's stages and changes come from the board's own `stage()` and `changed()`, so a step reads a spec as the board and the gate card do. `board.html` draws the strip from the JSON. No stage changes its steps: each stage already renders the board.

Relies on: D50 (one parser for spec rows), D62 (a script renders the board; Claude only publishes it), D63 (claude.ai page, localhost fallback), D64 (Mermaid 11.16.1). Drafted below: D71, D72, D73, D74.

```mermaid
flowchart TB
  ST["/spec, /build, /review, /ship"] -- "board.py render" --> B["board(): board.py:528"]
  B -- "root, shape, slice names" --> R["replay(): new"]
  R -- "rev-list, merge-base, cat-file --batch" --> G[(local git)]
  R -- "squash sha not in cache" --> GH["gh api commits/sha/pulls"]
  GH -- "PR number" --> F["git fetch origin refs/pull/N/head"]
  R -- "reads and writes" --> C[(docs/specs/.pages/replay-prs.json)]
  R -- "stage(), changed()" --> B
  B -- "JSON with replay" --> H["board.html: replayStrip()"]
```

`board()` calls `replay()`. It reads git, asks GitHub only for a squash commit that the cache does not know, and hands the steps back for `board.html` to draw.

```mermaid
sequenceDiagram
  participant S as /spec replay pause 3
  participant B as board.py
  participant G as git
  participant C as replay-prs.json
  participant H as gh and origin
  S->>B: render shape.md --by "/spec replay pause 3" --gate docs/specs/replay.md
  B->>G: rev-parse --show-toplevel (must be the root)
  B->>G: rev-list --reverse origin/main -- shape and 5 specs
  B->>G: rev-list --first-parent --no-merges origin/main -- same paths
  B->>C: look up caf25a7, 0ae3124, 2f594f4
  alt not in the cache
    B->>H: gh api repos/{owner}/{repo}/commits/caf25a7.../pulls
    H-->>B: 104
    B->>H: git fetch origin refs/pull/104/head
    B->>C: write caf25a7 → 104, e25a7c8
  end
  B->>G: rev-list --reverse merge-base..e25a7c8 -- paths
  B->>G: rev-list --reverse origin/main..HEAD -- paths
  B->>G: cat-file --batch: every sha:path, one process
  B->>B: stage() and changed() per step
  B-->>S: HTML with replay in its JSON, exit 0
```

On a cached run, the `alt` block does not run, and the render touches no network.

**How `replay()` builds the steps**

| Part | Rule |
| --- | --- |
| Guard | `git rev-parse --show-toplevel` must be the project root that `board()` found. Not a repo, or a repo above the root: steps `[]`, no note |
| Paths | The shape, and `docs/specs/<name>.md` for each slice in its Slices table |
| Main | `git symbolic-ref --short refs/remotes/origin/HEAD`, else `main`, else `master`. None: main is `HEAD`, and no branch is in flight |
| Steps from main | `git rev-list --reverse <main> -- <paths>`. This includes the commits of a branch merged with a merge commit |
| Squash candidates | `git rev-list --first-parent --no-merges <main> -- <paths>` |
| PR of a candidate | The cache, else `gh api repos/{owner}/{repo}/commits/<sha>/pulls --jq '[.[] \| select(.merged_at)][0].number'`. An answer that is not a whole number counts as no PR. No PR is cached as `null`, and the commit stays one step |
| PR commits | `git fetch origin refs/pull/<n>/head`, only when `git cat-file -e <head>` fails. Then `git rev-list --reverse $(git merge-base <head> <sha>^)..<head> -- <paths>`, in place of the squash commit |
| Branch in flight | `git rev-list --reverse <main>..HEAD -- <paths>`, after the rest |
| A step | `at` from `%ad` as `%Y-%m-%d %H:%M`, `hash` as `%h`, `subject` as `%s`, `pr` or null, `stages` by slice, `moved`, `changed` by file |
| Not read | `gh` missing, a non-zero exit, a timeout, or a failed fetch: the candidate stays one step, it is not cached, and `note` is `PR commits not read: <first stderr line>. Squash-merged slices show as one step.` |
| Any other error | Steps `[]`, and `note` is `Replay not read: <error>`. The render still exits 0 |

Every `git` and `gh` call runs with `GIT_TERMINAL_PROMPT=0` and `GH_PROMPT_DISABLED=1`, so it never waits for a password. Timeouts are 10 s for `gh` and 30 s for `fetch` (O6). The cache is written to a temporary file and then renamed.

### Changes

| File | What changes | Why |
| --- | --- | --- |
| `plugins/zuko/scripts/lib/board.py:528` | `board()` adds `"replay": replay(root, shape, names)` | Scenarios 1 to 5 |
| `plugins/zuko/scripts/lib/board.py` | New `replay()`, `run()` for one `git` or `gh` call with its timeout, `blobs()` for one `cat-file --batch` process, and `pr_of()` for the cache, `gh` and `fetch` | Scenarios 1, 3, 4 and 5 |
| `plugins/zuko/scripts/lib/board.py:1` | The docstring names the `replay` key, its cache file, and that `render` and `data` can call `gh` and `git fetch` | Scenarios 3 and 4 |
| `plugins/zuko/scripts/lib/board.html:104` | CSS for `.replay`, `.rp-bar`, `.rp-ticks`, `.rp-step` and `.rp-slices`. It reuses the `.mk` tags from the gate card and the stage colours | Scenarios 1 and 2 |
| `plugins/zuko/scripts/lib/board.html:279` | `renderIdea()` adds `<section class="replay" id="replay">` under the slice map. New `replayStrip()` and `showStep()`, from the preview without its buttons | Scenarios 1, 2, 4 and 5 |
| `plugins/zuko/references/visual-page.md` | Under "Idea board" › step 1: one sentence that `render` reads git history and can call `gh` and GitHub for squash-merged PRs, and that a failure shows only as a note on the board | Scenario 4 |
| `plugins/zuko/scripts/tests/test-replay.sh` | New. A fixture repo per case: the guard, the step list, the squash swap, the cache, `gh` missing, a failed fetch, and a subject with `<` in it | Scenarios 1 to 5 |
| `plugins/zuko/scripts/tests/test-e2e-replay.sh` | New. The e2e walk below | Scenarios 1 to 5 |
| `plugins/zuko/scripts/tests/test-board-dom.sh` | One more render: a strip with 3 steps. Checks that the last step shows first, that a subject with HTML in it shows as text, and the empty message | Scenarios 2 and 5 |

Reusing: `stage()` (`board.py:133`), `raw_sections()` (`:257`), `changed()` (`:362`), `slice_rows()` (`:103`), `blob()` (`:646`) for the escape into the script block, and the page's `esc()` and `MK` (`board.html:206`, `:329`).

### Earn-it

| Added | Triggered by |
| --- | --- |
| `gh api` lookup | Scenario 3: the squash commit has no PR number in its subject in this repo, so git alone cannot name the PR (O4) |
| `replay-prs.json` cache | O6: without it, each render at each stage asks GitHub once for each squash commit |
| One `cat-file --batch` process | 38 steps × 6 files is 228 reads. The prototype with one `git show` per read took 1.2 s per render |
| The toplevel guard | The test fixtures live under `/tmp`. Without the guard, a fixture inside another repo reads that repo's history |

### Non-functionals

|                      |                                                                               |
| -------------------- | ----------------------------------------------------------------------------- |
| **Load**             | One render per stage. living-board today: 38 steps, 15 KB of JSON, 3 squash commits, 228 file reads |
| **Breaks first**     | At 10×, 380 steps give about 150 KB of JSON and 2,300 reads in one process: still under a second. The slider then has 380 stops. Thin the ticks before the data |
| **Security surface** | Runs where the user runs the stage. Trusts commit subjects and spec text from git, which can come from PR authors: the JSON goes through `blob()`, and the page escapes each value with `esc()`. The PR number from `gh` must be a whole number before it reaches `git fetch`. Uses the user's existing `gh` login and git remote. Stores commit hashes and PR numbers in a git-ignored file |
| **Proof it works**   | `python3 board.py data docs/specs/living-board/shape.md --by x \| python3 -c 'import json,sys; r=json.load(sys.stdin)["replay"]; print(len(r["steps"]), r["note"])'` prints `38 None` on this branch with GitHub reached |
| **Rollout**          | No flag. The strip ships with the next release of zuko. Rollback: revert the commit, and the board draws as before. A stale `replay-prs.json` is harmless and can be deleted |

### Test plan

| Scenario | Test | Command |
| --- | --- | --- |
| 1. The board replays the idea's commits, oldest first | `test-replay.sh`, `test-e2e-replay.sh` | `bash plugins/zuko/scripts/tests/run.sh replay` |
| 2. A step shows what moved since the step before | `test-replay.sh`, `test-board-dom.sh` | `bash plugins/zuko/scripts/tests/run.sh board-dom` |
| 3. A squash-merged slice shows the commits of its PR | `test-e2e-replay.sh`, with a bare repo as `origin` that holds `refs/pull/1/head`, and a stub `gh` on `PATH` that prints `1` | `bash plugins/zuko/scripts/tests/run.sh e2e-replay` |
| 4. GitHub cannot be reached | `test-replay.sh`: a stub `gh` that exits 1, then no `gh` on `PATH` | `bash plugins/zuko/scripts/tests/run.sh replay` |
| 5. An idea with no commits yet | `test-replay.sh`, `test-board-dom.sh` | `bash plugins/zuko/scripts/tests/run.sh replay` |

**E2E:** `test-e2e-replay.sh`. In one fixture repo with a bare `origin`, it commits a shape and slice 1 and merges them with a merge commit. It then pushes slice 2's three pause commits as `refs/pull/1/head` and squashes them onto `main`, and opens slice 3 on a branch with two commits. It renders with a stub `gh`, and checks the step list, the swap, the stages per step and the cache. Then it renders again with `gh` removed from `PATH` and checks that the cache still gives the PR steps. The full suite runs with `bash plugins/zuko/scripts/tests/run.sh`.

### Chunks

| Chunk | Scenarios | Files owned |
| ----- | --------- | ----------- |
| A | 1, 3, 4, 5 (data) | `plugins/zuko/scripts/lib/board.py`, `plugins/zuko/references/visual-page.md`, `plugins/zuko/scripts/tests/test-replay.sh`, `plugins/zuko/scripts/tests/test-e2e-replay.sh` |
| B | 1, 2, 5 (page) | `plugins/zuko/scripts/lib/board.html`, `plugins/zuko/scripts/tests/test-board-dom.sh` |

The JSON shape in "How `replay()` builds the steps" is the contract between the chunks. Chunk B's DOM test writes its own JSON into the page, so it does not wait for chunk A.

### Risks

| Risk | Mitigation |
| --- | --- |
| A spec renamed in a later commit loses its earlier steps, because the paths come from the Slices table at HEAD | Accepted for v1. No slice has been renamed in this repo |
| `git gc` drops a fetched PR head, so the cache points to a missing commit | `cat-file -e` before use, then fetch again |
| GitHub's `commits/<sha>/pulls` gives an open PR that holds the same commit | Keep only PRs with `merged_at` set |
| A long history makes the slider hard to use | 38 steps today. Thin the ticks when a real idea passes 200 |
| The fetch writes objects into the user's repo | Objects only, no refs, and only for PRs that merged into `main`. `git gc` cleans them up |

### Decisions to record

```markdown
## D71 · 2026-10-26 · Replay finds a squash commit's PR with gh api, and reads its commits from refs/pull/N/head

Why: in this repo, gate-card, pr-gate and library each reached main as one squash commit, and only their PRs hold the pause commits. The squash subjects carry no PR number, and gh api names the PR exactly (caf25a7 → 104 in 0.6 s).
Rejected: main only (each squash-merged slice is one step), a stop log in each spec (every spec gains a section), matching PR heads by file content through git ls-remote (a guess when two PRs hold the same file).
Source: specs/replay.md
Status: active

## D72 · 2026-10-26 · A replay step holds the stages and the changes, not the whole board

Why: the user steps through how the idea moved. The stages and the gate card's change tags show that in about 0.4 KB a step, 15 KB for living-board's 38 steps.
Rejected: the whole board at each commit, with diagrams and panels (about 40 KB a step, 1.5 MB for 38).
Source: specs/replay.md
Status: active

## D73 · 2026-10-26 · A replay step changes only the Replay strip

Why: the board above shows the idea as it is now. A step card with its own stage chips never mixes past and present on one page.
Rejected: restaging the filmstrip and the rail at each step (the reader cannot tell at a glance which parts show the past).
Source: specs/replay.md
Status: active

## D74 · 2026-10-26 · Replay keeps its PR lookups in a git-ignored file, not in git refs

Why: a cached run touches no network. A file in docs/specs/.pages/ adds nothing to the user's repo, and a head that git gc drops is fetched again.
Rejected: refs under refs/zuko/pr/ (they show in git log --all and stay until removed by hand), no cache (one gh call per squash commit at every render).
Source: specs/replay.md
Status: active
```

## Open items

| ID  | What | Type | Raised at | Owner | Status | Answer |
| --- | ---- | ---- | --------- | ----- | ------ | ------ |
| O1  | Replay rebuilds frames from git history, but a spec is often written in one commit, so it may have only one or two frames. On `main`, gate-card, pr-gate and library are one squash commit each. Where do the lost frames come from? (from shape O9) | question | shape | user | Resolved | Main, plus each squash-merged PR's commits read from GitHub (`refs/pull/N/head`). Offline or with no GitHub remote, each squash-merged slice shows as one step. 2026-10-26 |
| O2  | What does a frame show: the stage of each slice and what changed, or the whole board as it was at that commit, with its diagrams and panels? | question | spec p1 | user | Resolved | The stage of each slice, the commit, and what changed since the frame before, with the gate card's tags. 2026-10-26 |
| O3  | Approved scenario 2 said the stage rail shows each slice as it was at that step. The step card now shows each slice's stage in its own chips, and the rest of the board stays at now, so it never mixes past and present. Is that right? | question | spec p2 | user | Resolved | Yes. The step card shows the stages, and the rest of the board stays at now. 2026-10-26 |
| O4  | How does `board.py` find which PR a squash commit on `main` came from? | question | spec p3 | user | Resolved | `gh api repos/{owner}/{repo}/commits/<sha>/pulls`. With no `gh`, or `gh` not logged in, the board shows the "PR commits not read" note. 2026-10-26 |
| O5  | Where does `board.py` keep the PR lookups, so it does not ask GitHub at every render? | question | spec p3 | user | Resolved | `docs/specs/.pages/replay-prs.json`, git-ignored. A head that `git gc` drops is fetched again. 2026-10-26 |
| O6  | A render reaches GitHub when `main` has a squash commit that the cache does not know. Each call has a timeout: 10 s for `gh`, 30 s for `fetch`. | flag | spec p3 | user | Accepted risk | Only a new squash commit costs a call, about 0.6 s each here. Later renders read the cache. 2026-10-26 |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **Step** — one point of the Replay strip: the idea as it was at one commit. The board's slice cards are already called frames, so replay does not use that word.
- **Squash merge** — merging a PR as one new commit on `main`. The PR's own commits stay on GitHub, but not on `main`.
- **Branch in flight** — the branch of the slice that is being worked on now and is not merged.
- **gh** — GitHub's command-line tool. `gh api` sends one request to the GitHub API as the logged-in user.
- **`refs/pull/N/head`** — the ref where GitHub keeps the last commit of PR number N, also after the PR merges.
- **`git cat-file --batch`** — one git process that prints many files from many commits, one after the other.
- **`git gc`** — git's cleanup. It deletes objects that no branch, tag or ref points to, after about two weeks.
- **e2e** — end-to-end: one test that walks the whole slice as a user would.
