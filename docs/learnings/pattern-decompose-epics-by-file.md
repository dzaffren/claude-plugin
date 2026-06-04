---
name: decompose-epics-by-file
description: in /build, group sub-tasks by file (disjoint sets) not by story when an epic's stories edit overlapping files
type: pattern
scope: plugin-general
captured: 2026-06-04
source: /build session (thinking-skills-quality) — two stories shared SKILL.md + evals.json files
---

When `/build` executes a multi-story epic whose stories edit OVERLAPPING files
(e.g. a shared `SKILL.md` and a shared `evals.json`), group the build sub-tasks
BY FILE — each sub-task owns a disjoint set of files — instead of following the
per-story implementation plans literally.

**Why:** `feature-builder` sub-tasks run in isolated worktrees in parallel and
merge independently; two sub-tasks editing the same file collide at merge.
File-disjoint partitioning is the property that keeps parallel merges
conflict-free. This session's epic had both stories touching the same three
`SKILL.md` files and three `evals.json` files; re-grouping by file produced
clean parallel batches with zero merge conflicts. Relates to
[[blocker-feature-builder-cannot-commit]].

**How to apply:** In `/build` Phase 2 (decomposition), before launching agents,
check whether the epic's stories share any target files. If they do, re-partition
the sub-tasks so each owns disjoint files; run the new-file-creation tasks first
(INDEPENDENT), then the file-edit tasks (one per shared file, folding in every
story's concern for that file).
