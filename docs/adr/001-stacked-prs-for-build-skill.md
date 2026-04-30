# ADR-001: Stacked PRs for Build Skill

**Status:** Proposed
**Date:** 2026-04-16
**Deciders:** Platform Team

## Context

The `/build` skill currently auto-merges all worktree branches into a single feature branch and raises one MR. Each worktree implements a user story from the spec, but the reviewer sees them as a single monolithic diff.

As specs grow to 3+ stories, MRs become large and hard to review. We are considering a stacked PR model where each story gets its own MR, giving reviewers focused, per-story diffs while keeping the feature branch as the integration point.

## Decision

_Pending team discussion._

## Options Considered

### Option A: Single MR (current)

```
base
 |
 +-- feature/epic ----------------------------------> base (1 MR)
          |                                            ^
          +-- worktree-1 --+                           |
          +-- worktree-2 --+-- auto-merged (Phase 3.5) +
          +-- worktree-3 --+
```

All worktree branches are auto-merged into the feature branch (Phase 3.5), then Phase 4 runs full verification on the combined result, and Phase 5 ships one MR.

| Pros                                                                                                                           | Cons                                                                                     |
| ------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| Full integration testing -- Phase 4 verifies the combined result before any code is pushed. Cross-story bugs are caught early. | Large MRs -- reviewers see all stories in one diff. Hard to review, easy to miss issues. |
| Simpler flow -- one branch, one MR, one review. No coordination overhead.                                                      | No incremental review -- review cannot start until every story is complete and merged.   |
| Atomic delivery -- the feature either ships completely or not at all.                                                          | Blast radius -- one broken story blocks the entire MR.                                   |

### Option B: Stacked PRs (merge gates)

```
base
 |
 +-- feature/epic ----------------------------------> base (epic MR)
          |                                            ^
          +-- story-1 ---- MR #1 --> feature/epic      |
          |                                            |
          +-- story-2 ---- MR #2 --> feature/epic      |
          |                                            |
          +-- story-3 ---- MR #3 --> feature/epic -----+
```

Each story branch creates an MR targeting the feature branch. The feature branch itself has an "epic MR" targeting base. Merging happens through MR approvals, not auto-merge.

| Pros                                                                                             | Cons                                                                                                                                                                |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Reviewable slices -- each story is reviewed in isolation, making reviews focused and manageable. | No combined verification before review -- Phase 4 can only verify each story branch in isolation. Integration issues between stories are only caught after merging. |
| Parallel review -- reviewers can start on story-1 while story-3 is still building.               | Coordination overhead -- SEQUENTIAL stories create implicit dependencies between MRs. Reviewers need to understand the merge order.                                 |
| Granular accountability -- each story MR has its own approval, CI status, and discussion thread. | Post-merge verification gap -- after all story MRs merge into the feature branch, a separate integration check is needed before the epic MR can be approved.        |
| Partial progress -- if story-3 is blocked, stories 1 and 2 can still be reviewed and approved.   | CI cost -- each story MR triggers its own pipeline, plus the epic MR needs a final run.                                                                             |

### Option C: Hybrid (auto-merge + stacked PRs for review)

```
base
 |
 +-- feature/epic ----------------------------------> base (epic MR)
          |                                            ^
          +-- story-1 --+                              |
          +-- story-2 --+-- auto-merged (Phase 3.5)    |
          +-- story-3 --+                              |
          |                                            |
          Phase 4 verifies combined result             |
          |                                            |
          Then push story branches + raise MRs --------+
```

Keep auto-merge (Phase 3.5) and full verification (Phase 4), but then retroactively push the original story branches and raise MRs for review. The code is already integrated and verified, but reviewers still see isolated, per-story diffs.

| Pros                                                                                        | Cons                                                                                                                                                                                              |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Full integration testing -- Phase 4 verifies the combined result before anything is pushed. | Story MRs are informational, not gatekeeping -- the code is already on the feature branch. Story MRs become review artifacts rather than merge gates.                                             |
| Reviewable slices -- reviewers still see per-story diffs, not one giant MR.                 | Slightly more complex workflow -- auto-merge + push story branches + raise story MRs + raise epic MR.                                                                                             |
| No verification gap -- stories are already proven to work together.                         | Review feedback is retroactive -- if a reviewer requests changes to story-2, the fix must be committed on the feature branch (since story-2 is already merged), then the story MR diff may drift. |

### Option D: Stacked PRs + auto-merge + verification

```
base
 |
 +-- feature/epic ------------------------------------------> base (epic MR)
          |                                                    ^
          +-- story-1 ---- MR #1 --> feature/epic              |
          +-- story-2 ---- MR #2 --> feature/epic              |
          +-- story-3 ---- MR #3 --> feature/epic              |
          |                                                    |
          All story MRs raised (reviewers can browse)          |
          |                                                    |
          Auto-merge all story branches into feature/epic      |
          |                                                    |
          Phase 4 verifies combined result                     |
          |                                                    |
          Epic MR ready for approval ----->--------------------+
```

Follows Option B's branching model — each story gets its own branch and MR targeting the feature branch. But instead of waiting for manual MR approvals to merge, the build skill auto-merges all story branches into the feature branch after raising the MRs, then runs Phase 4 verification on the combined result.

Story MRs remain as **navigable records** — reviewers can browse each story's diff in isolation even though the code is already integrated. The epic MR is the actual merge gate.

**Handling review feedback:** Any changes requested during review are committed directly on the feature branch (not on the original story branches). The story MR diffs are frozen snapshots of what was originally built — the epic MR always shows the true final state. This keeps the workflow simple: one place to commit fixes, one MR to approve for merge.

| Pros                                                                                                                                           | Cons                                                                                                                                                         |
| ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Full integration testing -- Phase 4 verifies the combined result after auto-merge. Cross-story bugs are caught before the epic MR is approved. | Story MRs are not true merge gates -- code is auto-merged regardless of approval. Review feedback requires follow-up commits on the feature branch.          |
| Reviewable slices -- each story MR is a permanent, browsable record. Reviewers can navigate story-by-story instead of reading one large diff.  | More moving parts -- raise MRs + auto-merge + verify + epic MR. More branches and MRs to manage than Option A.                                               |
| Atomic verification -- like Option A, the feature is verified as a whole before the epic MR is approved.                                       | Story MR diffs may become stale -- if review feedback leads to changes on the feature branch, the original story MR diffs no longer reflect the final state. |
| Traceability -- story MRs link back to the spec's sub-tasks, making it easy to audit which story introduced which changes.                     | CI cost -- story MR pipelines may run on pre-integration code that doesn't reflect the final combined state.                                                 |

## Comparison

| Aspect                | Option A (Single MR)                            | Option B (Stacked gates)           | Option C (Post-merge MRs)                      | Option D (Stacked + auto-merge)                                            |
| --------------------- | ----------------------------------------------- | ---------------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------- |
| Story MRs are...      | None                                            | Merge gates                        | Raised after merge                             | Raised before merge, auto-merged                                           |
| Integration testing   | Before push                                     | After manual merge                 | Before push                                    | Before epic approval                                                       |
| Review experience     | One large diff                                  | Per-story, unverified              | Per-story, retroactive                         | Per-story, navigable                                                       |
| Review blocks merge?  | Yes (single MR)                                 | Yes (per story)                    | No                                             | No (epic MR is the gate)                                                   |
| Workflow complexity   | Low                                             | Medium                             | Medium                                         | Medium-high                                                                |
| Review feedback fix   | Commit on the MR branch, diff updates naturally | Commit on story branch, re-merge   | Commit on feature branch, story MR diffs drift | Commit on feature branch, story MR diffs frozen; epic MR shows final state |
| Final source of truth | The single MR                                   | Epic MR after all story MRs merged | Epic MR                                        | Epic MR                                                                    |

## Open Questions

1. Which option does the team prefer? Key tradeoff axis: **review-as-gate** (Option B) vs **review-as-navigation** (Options C, D) vs **single review** (Option A).
2. For Option B: should we add a "post-merge verification" step that runs after all story MRs are merged into the feature branch but before the epic MR is approved?
3. For Options B/D: for SEQUENTIAL stories, should each story MR target the previous story's branch (true stacking) or all target the feature branch?
4. Does the team's GitLab workflow support stacked MRs well, or would tooling friction outweigh the benefits?
5. For Option D: when a reviewer requests changes on a story MR after auto-merge, should the fix be committed on the feature branch directly, or on the story branch and re-merged?

## Consequences

_To be filled after decision is made._
