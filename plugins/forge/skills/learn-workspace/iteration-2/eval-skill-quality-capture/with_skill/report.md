# Learn skill eval — skill-quality capture

## Result

CAPTURED: `skill-prd-refine-missing-migrations`

## Details

- **Type:** `skill-quality` (chosen because of recurring-failure signals — "keeps missing" / "happened again" / "reviewer had to send it back" — pointing at a specific skill).
- **Slug used:** `prd-refine-missing-migrations`
- **Full filename:** `docs/learnings/skill-prd-refine-missing-migrations.md`
- **Frontmatter `skill:` field present:** yes — `skill: prd-refine`
- **Body `**Skill:**` line present:** yes — `**Skill:** prd-refine`
- **Index created:** yes — `docs/learnings/INDEX.md` with one entry pointing at the new file.
- **CLAUDE.md updated:** yes — added a new `## Learnings` section (did not exist before) with a single bullet referencing the learning file. Triggered by absolute-language signal: "We should always".
- **Dedupe:** no prior `docs/learnings/` existed in this greenfield fixture, so no duplicate check hit.

## Writes

All three writes succeeded:

1. `/home/chrisng/dev/mjolnir/plugins/forge/skills/learn-workspace/iteration-2/eval-skill-quality-capture/with_skill/repo/docs/learnings/INDEX.md` — created.
2. `/home/chrisng/dev/mjolnir/plugins/forge/skills/learn-workspace/iteration-2/eval-skill-quality-capture/with_skill/repo/docs/learnings/skill-prd-refine-missing-migrations.md` — created with `skill: prd-refine` frontmatter and `**Skill:** prd-refine` body line.
3. `/home/chrisng/dev/mjolnir/plugins/forge/skills/learn-workspace/iteration-2/eval-skill-quality-capture/with_skill/repo/CLAUDE.md` — appended `## Learnings` section.

## Rule recorded

When `/prd-refine` plans touch a model file (e.g. `prisma/schema.prisma`), the Implementation Plan must include a dedicated migration sub-task naming the migration file path. Reviewer sent APP-201 back for missing this; it has recurred across specs.
