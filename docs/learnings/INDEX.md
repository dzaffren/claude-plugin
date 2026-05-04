# Learnings Index

Per-repo learnings captured by the `/learn` skill. Each entry points to a
file in this directory. The active ruleset is synced into the repo's
`CLAUDE.md` under `## Learnings`.

- [Skill step numbering vs. data deps](blocker-skill-step-numbering-vs-data-deps.md) — producer steps must run before consumers; verify before shipping
- [git checkout destroys uncommitted work](blocker-git-checkout-destroys-uncommitted-work.md) — never use `git checkout -- <files>` to revert an auto-applied patch on a dirty tree; use `git apply -R`
- [code-reviewer gate before commit](win-code-reviewer-gate-before-commit.md) — /ship Step 0.5 gate caught two fail-severity bugs on day one
- [/ship bump-semver misses plugin manifests](skill-ship-bump-semver-misses-plugin-manifests.md) — Step 3e does not recognize `plugin.json` / `marketplace.json`, so feature ships leave versions stale
- [/ship has no CHANGELOG release rotation](skill-ship-no-changelog-release-rotation.md) — no step cuts `[Unreleased]` into a version heading, so releases require a manual follow-up
- [Spec-driven build clean merge](win-spec-driven-build-clean-merge.md) — rigorous `/prd` → `/prd-refine` → `/build` pipeline produced 4 clean-merging sub-tasks with 6/6 acceptance criteria on first try
- [Feature-builder cannot commit](blocker-feature-builder-cannot-commit.md) — worktree-isolated agents are denied `git add`/`commit`; parent session must commit on their behalf
- [Skills load at session start](blocker-skills-load-at-session-start.md) — mid-session edits to a skill don't hot-reload; new content takes effect next session
- [/ship metadata.version can regress](skill-ship-metadata-version-can-regress.md) — multi-plugin marketplace edge case deferred in PR #6; fix before a second plugin ships
- [README single source of truth](pattern-readme-single-source-of-truth.md) — README carries one `**Current version:**` line; no version-specific prose; CHANGELOG owns release history (deferred plan recorded)
