# Learnings Index

Per-repo learnings captured by the `/learn` skill. Each entry points to a
file in this directory. The active ruleset is synced into the repo's
`CLAUDE.md` under `## Learnings`.

> **Scope note:** this directory currently mixes two kinds of learnings —
> `scope: plugin-general` (facts about how the forge plugin behaves, which
> should eventually migrate to `plugins/forge/docs/known-issues.md`) and
> `scope: project-specific` (decisions specific to this particular repo).
> Starting 2026-05-04, new entries declare a `scope:` field in frontmatter.
> See `skill-learn-conflates-plugin-and-project-scope.md` for the migration
> plan.

- [Skill step numbering vs. data deps](blocker-skill-step-numbering-vs-data-deps.md) — producer steps must run before consumers; verify before shipping
- [git checkout destroys uncommitted work](blocker-git-checkout-destroys-uncommitted-work.md) — never use `git checkout -- <files>` to revert an auto-applied patch on a dirty tree; use `git apply -R`
- [code-reviewer gate before commit](win-code-reviewer-gate-before-commit.md) — /ship Step 0.5 gate caught two fail-severity bugs on day one
- [/ship bump-semver misses plugin manifests](skill-ship-bump-semver-misses-plugin-manifests.md) — Step 3e does not recognize `plugin.json` / `marketplace.json`, so feature ships leave versions stale
- [/ship has no CHANGELOG release rotation](skill-ship-no-changelog-release-rotation.md) — no step cuts `[Unreleased]` into a version heading, so releases require a manual follow-up
- [Spec-driven build clean merge](win-spec-driven-build-clean-merge.md) — rigorous `/prd` → `/prd-refine` → `/build` pipeline produced 4 clean-merging sub-tasks with 6/6 acceptance criteria on first try
- [Feature-builder cannot commit](blocker-feature-builder-cannot-commit.md) — worktree-isolated agents are denied `git add`/`commit`; parent session must commit on their behalf
- [Skills load at session start](blocker-skills-load-at-session-start.md) — mid-session edits to a skill don't hot-reload; new content takes effect next session
- [/ship metadata.version can regress](skill-ship-metadata-version-can-regress.md) — multi-plugin marketplace edge case deferred in PR #6; fix before a second plugin ships
- [README single source of truth](pattern-readme-single-source-of-truth.md) — README carries one `**Current version:**` line; no version-specific prose; CHANGELOG owns release history (deferred plan recorded) — `scope: project-specific`
- [/learn conflates plugin and project scope](skill-learn-conflates-plugin-and-project-scope.md) — `/forge:learn` mixes plugin-general and project-specific facts in one directory; migration plan recorded — `scope: plugin-general`
- [/ship bump-semver silently no-ops without jq](skill-ship-bump-semver-silent-noop-without-jq.md) — a missing `jq` makes Step 3e skip the release bump as if docs-only, leaving feature versions stale — `scope: plugin-general`
- [Editing forge's own skills is a self-referential build](blocker-skill-edits-self-referential-build.md) — no automated tests apply and the active plugin loads from the install cache, not the worktree — `scope: project-specific`
- [Branch new work from the integration base](blocker-branch-new-work-from-integration-base.md) — `git checkout -b` branches from the current branch; start independent work from `main` or it inherits other commits — `scope: plugin-general`
- [Adversarial multi-dimension review for skill changes](win-adversarial-multi-dimension-review-for-skill-changes.md) — a per-dimension adversarial review caught real latent bugs in a build-loop skill change before ship — `scope: plugin-general`
- [code-reviewer `manual` is a fix-type, not a severity](convention-code-reviewer-manual-is-fix-type-not-severity.md) — classify findings by severity (fail/warn/info); a fail+manual finding is still blocking — `scope: plugin-general`
- [Defer version bumps in concurrent-PR sessions](pattern-defer-version-bump-in-concurrent-pr-sessions.md) — don't bump per-PR when several are open off one base; accumulate under `[Unreleased]` and release once — `scope: project-specific`
