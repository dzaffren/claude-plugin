---
name: ship-bump-semver-misses-plugin-manifests
description: /forge:ship Step 3e bump-semver.sh does not recognize Claude-plugin manifests, so feature ships leave versions stale
type: skill-quality
captured: 2026-05-04
source: /ship — PR #3 merge, discovered during v0.3.0-alpha release
skill: ship
---

`/forge:ship` Step 3e calls `plugins/forge/skills/ship/scripts/bump-semver.sh`
to derive and apply a semver bump based on the commit range. The script only
recognizes standard-ecosystem manifests: `package.json`, `pyproject.toml`,
`Cargo.toml`, `go.mod`, `Gemfile`, `.csproj`. It does **not** recognize
Claude-plugin manifest shapes — `plugins/<name>/.claude-plugin/plugin.json`
and top-level `.claude-plugin/marketplace.json`. In this repo the script
returns `manifest: none` every time, and Step 3e silently skips the bump.

**Why:** The result is that feature ships merge to `main` with stale
versions (e.g. three `feat` commits merged via PR #3 but versions stayed
`0.2.0-alpha`). The user then has to cut a separate release PR by hand
(PR #4) to bump versions, rotate `[Unreleased]`, and update the README.
That defeats the point of an "atomic-commit, semver-aware" `/ship` — and
it's easy to forget entirely, leaving shipped code with mislabeled versions
on the marketplace.

**How to apply:** When working on `/forge:ship` or the release scripts in
this repo:

1. Extend `bump-semver.sh` to detect and bump these manifest shapes:
   - `plugins/*/.claude-plugin/plugin.json` — single `version` field
   - `.claude-plugin/marketplace.json` — both `metadata.version` and
     `plugins[].version` (one per plugin entry)
2. Ensure all occurrences update atomically — writing one version and
   forgetting the other would produce a mismatch between marketplace
   metadata and plugin manifest.
3. Update the `<manifest>` column the script prints so it emits something
   like `multi:plugin.json+marketplace.json` to signal multi-file bumps.
4. While you're there, consider rotating `[Unreleased]` in `CHANGELOG.md`
   as part of the release commit (separate learning, see
   `skill-ship-no-changelog-release-rotation.md`).

**Skill:** ship

**What was tried:** v0.3.0-alpha was cut manually in PR #4 by editing all
three version fields by hand and invoking
`update-changelog.sh --release 0.3.0-alpha` directly. That works but
undermines `/ship` as the single entry point for shipping.
