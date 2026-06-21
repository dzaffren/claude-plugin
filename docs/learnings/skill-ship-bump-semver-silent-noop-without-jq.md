---
name: ship-bump-semver-silent-noop-without-jq
description: bump-semver.sh degrades silently to manifest=none when jq is absent, and /ship Step 3e mistakes that for a docs-only ship, leaving feature versions stale
type: skill-quality
captured: 2026-06-21
source: /ship — Story 3 plain-language-trust-layer 0.6.0 release (bumped by hand)
scope: plugin-general
---

`plugins/forge/skills/ship/scripts/bump-semver.sh` reads every version through
`jq` (the Claude-plugin path at lines ~138-144, the `package.json` path at line
~81, and every apply-time write at ~187 and ~214-237). Each `jq` call is guarded
by `2>/dev/null || true`. When `jq` is not on `PATH`, the "command not found" is
swallowed, the captured version stays empty, `IN_SCOPE_PLUGINS` never populates,
and the script prints `<level> 0.0.0 <new> none` — e.g. `minor 0.0.0 0.1.0 none`.

`/forge:ship` Step 3e's skip rule (`ship/SKILL.md` lines 211-213: "if `<level>`
is `none` or `<manifest-summary>` is `none`, skip … docs-only ships and repos
with no detectable manifest") then misclassifies the missing-`jq` degradation as
a benign docs-only ship and silently skips the release bump.

**Why:** On a real feature ship this leaves `plugin.json`, `marketplace.json`,
`README.md`, and `CHANGELOG.md` at the old version with **no warning** — the exact
stale-version failure the 0.4.0 release automation was built to prevent. It is
broader than the Claude-plugin path: a missing `jq` also breaks `package.json`
repos, since those reads and writes route through `jq` too. Distinct from
[[skill-ship-bump-semver-misses-plugin-manifests]], which is about *unrecognized*
manifest shapes — this is a *recognized manifest but missing tooling* failure.

**How to apply:** When touching `bump-semver.sh` or `/ship` Step 3e:

1. Make `bump-semver.sh` detect a missing `jq` (`command -v jq`) before the
   version reads and emit a loud stderr warning plus a distinct non-`none`
   signal (or non-zero exit), so the degradation is never silent.
2. And/or have Step 3e distinguish three cases instead of two — (a) no manifest
   in repo, (b) docs-only commit range, (c) manifest present but required tooling
   unavailable. Only (a) and (b) are safe to skip; (c) must stop and warn.
3. Until fixed, when shipping a feature in an environment without `jq`, bump
   manually: edit the version fields (or `sed` them) across `plugin.json`,
   `marketplace.json` (both `metadata.version` and the plugin entry), and the
   README `**Current version:**` line, then run `update-changelog.sh --release
   <new>` (it uses python3, which is present).

**Skill:** ship
