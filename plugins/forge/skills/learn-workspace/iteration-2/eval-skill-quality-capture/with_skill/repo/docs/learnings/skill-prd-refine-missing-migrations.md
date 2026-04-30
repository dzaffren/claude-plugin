---
name: prd-refine-missing-migrations
description: prd-refine omits migration sub-tasks when the plan touches a model file
type: skill-quality
captured: 2026-04-28
source: /learn — recurring correction noticed on APP-201 spec review
skill: prd-refine
---

When a plan touches a model file, `prd-refine` must always include a
dedicated database migration sub-task in the Implementation Plan.

**Why:** This has recurred across multiple specs — most recently APP-201,
where the reviewer sent the spec back because no migration sub-task was
listed despite new models being added. In this repo models live under
Prisma (`prisma/schema.prisma`), and any new model change requires a
paired migration under `prisma/migrations/` shipped in the same PR. When
`prd-refine` produces a plan without that sub-task, `/build` proceeds
without scaffolding the migration and the PR fails review.

**How to apply:** When running `/prd-refine` against this repo, inspect
the Implementation Plan before approving. If any sub-task changes a model
file (e.g. `prisma/schema.prisma`, or anything under a `models/`
directory), verify there is a separate sub-task for the matching
migration with the migration file path listed. If it is missing, add it
explicitly — do not approve a model-touching plan without a migration
sub-task.

**Skill:** prd-refine
