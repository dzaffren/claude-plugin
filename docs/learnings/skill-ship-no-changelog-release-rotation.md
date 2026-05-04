---
name: ship-no-changelog-release-rotation
description: /forge:ship has no step that rotates [Unreleased] into a version heading, so releases require a manual follow-up
type: skill-quality
captured: 2026-05-04
source: /ship — v0.3.0-alpha release (PR #4)
skill: ship
---

`/forge:ship` Step 3c appends entries to `[Unreleased]` in `CHANGELOG.md`
for each non-skipped commit, and Step 3e derives (but does not always
apply) a semver bump. However there is **no step that cuts the release** —
nothing renames `[Unreleased]` to `[<new-version>] - <date>` and seeds a
fresh empty `[Unreleased]` above it. `update-changelog.sh` ships with a
`--release <version>` mode that does exactly this rotation, but `/ship`
never calls it.

**Why:** In practice, every ship "accumulates" entries under `[Unreleased]`
until a human notices the stale state and cuts a manual release PR.
Inconsistent: the rest of the pipeline is automated, but the cut step
requires human intervention and is easy to forget.

**How to apply:** When working on `/forge:ship`:

1. Add a Step 3f — Release cut, gated on Step 3e producing a real bump
   (`<level> != none` **and** `<manifest> != none`):
   - Read the new version from Step 3e output.
   - Run `bash ${CLAUDE_SKILL_DIR}/scripts/update-changelog.sh --release <new-version>`.
   - Stage `CHANGELOG.md` and fold it into the `chore(release): bump to
<new>` commit created by Step 3e (single commit, no extra history).

2. Do **not** cut the release on every ship — only when the semver bump
   is non-zero. Feature branches that produce no bump keep accumulating
   entries under `[Unreleased]`.

3. Update the README once per major/minor bump — flag this separately if
   README staleness becomes its own pattern (it did on v0.1 → v0.3).

**Skill:** ship

**What was tried:** v0.3.0-alpha rotation was done manually in PR #4 by
invoking `bash plugins/forge/skills/ship/scripts/update-changelog.sh --release 0.3.0-alpha --date 2026-05-04`
from the shell, then staging and committing the result alongside the
manifest bumps and README refresh. Works, but fragments the release into
a manual follow-up PR.
