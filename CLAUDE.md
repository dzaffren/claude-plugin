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
- **README single source of truth** — `README.md` stays evergreen with one `**Current version:** <x.y.z>` line; no version-specific prose (`What's in vX`, `What's new in vX`). `CHANGELOG.md` owns release history; README links to it. Full restructure plan recorded in `docs/learnings/pattern-readme-single-source-of-truth.md` — wait for user to ask before actioning.
- **/learn conflates plugin and project scope** — `/forge:learn` writes both plugin-general facts and project-specific decisions into the same `docs/learnings/` directory. Plugin-general facts should eventually live in `plugins/forge/docs/known-issues.md` so they ship with the plugin. New entries declare a `scope:` field in frontmatter (`plugin-general` or `project-specific`); existing 8 entries are unlabeled and lazy-migrate. See `docs/learnings/skill-learn-conflates-plugin-and-project-scope.md`.
