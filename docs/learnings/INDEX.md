# Learnings Index

Per-repo learnings captured by the `/learn` skill. Each entry points to a
file in this directory. The active ruleset is synced into the repo's
`CLAUDE.md` under `## Learnings`.

- [Skill step numbering vs. data deps](blocker-skill-step-numbering-vs-data-deps.md) — producer steps must run before consumers; verify before shipping
- [git checkout destroys uncommitted work](blocker-git-checkout-destroys-uncommitted-work.md) — never use `git checkout -- <files>` to revert an auto-applied patch on a dirty tree; use `git apply -R`
- [code-reviewer gate before commit](win-code-reviewer-gate-before-commit.md) — /ship Step 0.5 gate caught two fail-severity bugs on day one
- [/ship bump-semver misses plugin manifests](skill-ship-bump-semver-misses-plugin-manifests.md) — Step 3e does not recognize `plugin.json` / `marketplace.json`, so feature ships leave versions stale
- [/ship has no CHANGELOG release rotation](skill-ship-no-changelog-release-rotation.md) — no step cuts `[Unreleased]` into a version heading, so releases require a manual follow-up
