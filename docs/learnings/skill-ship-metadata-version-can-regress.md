---
name: ship-metadata-version-can-regress
description: In a multi-plugin marketplace, /forge:ship Step 3e could regress `metadata.version` when the highest-versioned plugin was not in the diff's scope — fixed
type: skill-quality
captured: 2026-05-04
resolved: 2026-05-04
source: /ship — PR #6 code-reviewer finding (deferred); fix bundled into README single-source-of-truth ship
skill: ship
---

**Status:** Fixed. `bump-semver.sh` now computes `metadata.version` as the
max across ALL `plugins[].version` entries (in-scope and out-of-scope)
using `sort -V`. Regression guard: Scenario 6 in
`plugins/forge/skills/ship/scripts/__verify__/bump-semver-scenarios.sh`
seeds `alpha=2.5.0`, `forge=1.0.0`, feat-commits only to `forge`, and
asserts `metadata.version` stays at `2.5.0` after apply.

The historical context below is preserved for traceability.

---

The new Claude-plugin branch of `bump-semver.sh` (shipped in PR #6)
computes `NEW` from the max version among **in-scope** plugins only,
then writes that value to `.claude-plugin/marketplace.json`'s
`metadata.version`. If the marketplace's `metadata.version` already
tracks a higher-versioned **out-of-scope** plugin, the apply
overwrites it downward — a silent regression.

**Why:** Example concretely. A marketplace has two plugins:

```
plugins/forge/  → plugin.json version 1.0.0
plugins/alpha/  → plugin.json version 2.5.0
marketplace.json → metadata.version 2.5.0, plugins[].version matches
```

A `feat` commit touches only `plugins/forge/`. The new detection
branch sees only `forge` in scope, reads its version `1.0.0` as `OLD`,
computes `NEW=1.1.0`, and writes:

```
plugins/forge/plugin.json → 1.1.0           # correct
marketplace.json plugins[forge] → 1.1.0    # correct
marketplace.json metadata.version → 1.1.0   # REGRESSION from 2.5.0
```

The marketplace-level `metadata.version` now falsely claims the
marketplace is at `1.1.0` even though `alpha` is still at `2.5.0`.

**How to apply:** This repo is single-plugin today, so the bug is
dormant. Before a second plugin lands:

1. Extend `bump-semver.sh` to compute the marketplace's next
   `metadata.version` as `max(new_in_scope_version, existing_out_of_scope_versions)`.
   Concretely: gather current versions of ALL `plugins[].version`
   entries, replace the in-scope ones with `NEW`, take the highest,
   write that to `metadata.version`.
2. Add a scenario to
   `plugins/forge/skills/ship/scripts/__verify__/bump-semver-scenarios.sh`
   that seeds `metadata.version=2.5.0` and `alpha=2.5.0` and
   `forge=1.0.0`, pumps a feat-commit scoped only to forge, and
   asserts: `forge=1.1.0`, `alpha=2.5.0` unchanged, `metadata.version=2.5.0`
   (still, not regressed to 1.1.0).
3. The harness fix without the script fix will RED. Then write the
   script fix. Standard TDD.

**Skill:** ship

**What was tried:** PR #6 code-reviewer flagged this as `info` severity
with a note: "spec marks pre-release / marketplace-rollup semantics
out of scope — raise with spec owner." Spec owner (user) chose to
defer. Captured as skill-quality so the next spec touching `/ship`
sees this in the prior-learnings surfacing step and can bundle the fix.
