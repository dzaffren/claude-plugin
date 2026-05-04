# `bump-semver.sh` verification scripts

This directory contains hand-rolled verification scripts for `bump-semver.sh`.
There is no test framework (bats/shunit2) — these are portable bash scripts any
contributor can run after editing the script. Each script builds its own
throwaway git repo under `/tmp/`, runs the helper under test, asserts the
output, and cleans up on exit.

## Scripts

### `test-sub1.sh`

Covers the Claude-plugin manifest **detection** branch added in sub-task 1
of the `ship-release-automation` spec (T1.1–T1.4). Verifies that
`bump-semver.sh` recognizes `plugins/<slug>/.claude-plugin/plugin.json`
alongside `.claude-plugin/marketplace.json`, that standard manifests
(`package.json`) still win when both are present, and that the branch
short-circuits when no plugin source files are in the diff.

Run: `bash plugins/forge/skills/ship/scripts/__verify__/test-sub1.sh`
Expected exit code: `0` (all 4 scenarios pass).

### `test-sub2.sh`

Covers the Claude-plugin **`--apply`** branch added in sub-task 2 (T2.1–T2.5).
Verifies that applying a bump writes every in-scope `plugin.json`, updates
the matching `plugins[].version` entries in `marketplace.json`, bumps
`metadata.version`, leaves untouched plugins byte-identical, and is idempotent
when re-run over a range that already contains the `chore(release)` commit.

Run: `bash plugins/forge/skills/ship/scripts/__verify__/test-sub2.sh`
Expected exit code: `0` (all 13 assertions pass).

### `bump-semver-scenarios.sh`

End-to-end harness that maps directly to the spec's Acceptance Criteria.
Seven scenarios in one script:

1. Single-plugin happy path (plugin + marketplace at `0.3.0-alpha` + a `feat`;
   also asserts the README `**Current version:**` line is rewritten).
2. Docs-only range (no writes, `none 0.0.0 0.0.0 none`).
3. Multi-plugin repo (both plugins at `1.0.0`) where only one plugin is in
   the diff; untouched plugin stays byte-identical.
4. Standard `package.json` repo — backwards compatibility with non-plugin
   repos; also asserts README rewrite on the standard-manifest branch.
5. Claude-plugin repo with no `CHANGELOG.md` — full `bump-semver.sh` →
   `update-changelog.sh --release` chain. The changelog script must print
   `no CHANGELOG.md in cwd; skipping` on stderr and exit 0.
6. Multi-plugin regression guard: `metadata.version=2.5.0` from out-of-scope
   `alpha`, feat commit scoped to `forge` (at `1.0.0`). After apply,
   `metadata.version` must STAY at `2.5.0`, not regress to `1.1.0`.
7. Multi-plugin SemVer pre-release ordering guard: out-of-scope `alpha` at
   `2.0.0-beta`, in-scope `forge` at `1.0.0` bumped to `1.1.0`. Under plain
   `sort -V`, `2.0.0-beta` sorts higher than any clean release — the
   opposite of SemVer 2.0.0. The fix prefers clean releases, so
   `metadata.version` must land at `1.1.0` (not `2.0.0-beta`).

Run: `bash plugins/forge/skills/ship/scripts/__verify__/bump-semver-scenarios.sh`
Expected exit code: `0`. Prints a `N/7 scenarios passed` summary on stdout.

## Known limitation: pre-release tag stripping

`compute_new()` in `bump-semver.sh` strips pre-release tags (e.g. `-alpha`)
from the patch component before incrementing. As a result, a minor bump of
`0.3.0-alpha` produces `0.4.0` (not `0.4.0-alpha`). Scenario 1 in
`bump-semver-scenarios.sh` asserts the actual behavior (`0.4.0`). The spec's
Acceptance Criteria mention `0.4.0-alpha` as a theoretical target; restoring
pre-release tags across bumps is out of scope for this change (see spec Scope
→ Out of scope: "Pre-release version semantics"). Do NOT modify
`compute_new()` to work around this without a new spec.

## When to run which

Run all three after any change to `bump-semver.sh`:

```bash
bash plugins/forge/skills/ship/scripts/__verify__/test-sub1.sh
bash plugins/forge/skills/ship/scripts/__verify__/test-sub2.sh
bash plugins/forge/skills/ship/scripts/__verify__/bump-semver-scenarios.sh
```

`test-sub1.sh` and `test-sub2.sh` are focused unit harnesses per sub-task;
`bump-semver-scenarios.sh` is the end-to-end check mapping to the spec's
Acceptance Criteria and exercises the `bump-semver.sh` →
`update-changelog.sh` chain together. All three must exit 0 before shipping
a change to the script.
