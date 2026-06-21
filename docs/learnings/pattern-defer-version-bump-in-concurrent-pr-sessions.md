---
name: defer-version-bump-in-concurrent-pr-sessions
description: When several PRs are open concurrently off the same base, don't cut a per-PR version bump — accumulate CHANGELOG entries under [Unreleased] and release once later
type: pattern
captured: 2026-06-21
source: /ship — multi-PR build-loop session
scope: project-specific
---

When multiple feature/fix PRs are open at once off the same base, cutting a
`chore(release)` version bump in each one causes version regressions or
collisions on `main` depending on merge order (e.g. a branch based on `0.5.0`
bumping to `0.5.1` while another already merged `0.6.0`).

**Why:** This session ran discovery → prd → prd-refine → build plus two fixes as
several concurrent PRs; per-PR bumps would have fought each other on merge (and
the jq-less shell couldn't auto-bump anyway).

**How to apply:** In a multi-PR session, commit the change yourself so `/ship`
enters at the push step and skips Step 3e's bump (or otherwise skip the bump);
let `update-changelog.sh <type>` entries accumulate under `[Unreleased]`, and
rotate `[Unreleased]` into a dated version on a single later release ship, once
the concurrent PRs have merged. Make sure `jq` is installed so the auto-bump
actually fires when you cut that release
([[ship-bump-semver-silent-noop-without-jq]]).
