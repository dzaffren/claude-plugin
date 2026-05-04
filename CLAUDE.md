# CLAUDE.md

Guidance for Claude Code when working on this repo (the forge plugin).

## Learnings

- **Skill step numbering vs. data deps** — In any skill with numbered steps, confirm the producer step runs before every consumer and that the producer's contract explicitly records the value it returns. See `docs/learnings/blocker-skill-step-numbering-vs-data-deps.md`.
- **git checkout destroys uncommitted work** — Never use `git checkout -- <files>` (or `git restore <files>`) to revert an auto-applied patch when the working tree has other uncommitted changes. Use `git apply -R <patch>` instead. See `docs/learnings/blocker-git-checkout-destroys-uncommitted-work.md`.
- **code-reviewer gate before commit** — Keep `/ship` Step 0.5 as a blocking gate; walk through FAIL findings individually rather than bulk-accepting. See `docs/learnings/win-code-reviewer-gate-before-commit.md`.
- **/ship bump-semver misses plugin manifests** — `bump-semver.sh` does not recognize `plugin.json` or `marketplace.json`, so Step 3e no-ops in this repo and releases require a manual bump. See `docs/learnings/skill-ship-bump-semver-misses-plugin-manifests.md`.
- **/ship has no CHANGELOG release rotation** — no step rotates `[Unreleased]` into a dated version heading; releases currently need a manual `update-changelog.sh --release` run. See `docs/learnings/skill-ship-no-changelog-release-rotation.md`. (Superseded by PR #6 — keep entry for historical context.)
- **Feature-builder agents cannot commit** — worktree-isolated `feature-builder` agents are denied `git add` / `git commit`; parent session commits their work. See `docs/learnings/blocker-feature-builder-cannot-commit.md`.
- **Skills load at session start** — editing a skill mid-session doesn't hot-reload it; new skill content takes effect only in the next session. See `docs/learnings/blocker-skills-load-at-session-start.md`.
- **/ship metadata.version can regress** — multi-plugin marketplace edge case: if the highest-versioned plugin is not in the ship diff, `metadata.version` can silently regress. Deferred in PR #6; fix before a second plugin ships. See `docs/learnings/skill-ship-metadata-version-can-regress.md`.
