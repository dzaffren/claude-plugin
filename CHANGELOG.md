# Changelog

All notable changes to the forge plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Fixed
- bump-semver.sh fails loudly when jq is missing and a version bump is required, instead of silently reporting manifest=none (which let /ship skip the bump)

## [0.6.0] - 2026-06-21

### Added
- plain-language & trust standard across the pipeline: plain wording, a stated reason behind every recommendation, and technical detail on demand

### Learnings

- **ship-bump-semver-silent-noop-without-jq** (skill-quality) — bump-semver.sh degrades silently to manifest=none when jq is absent, and /ship Step 3e mistakes that for a docs-only ship, leaving feature versions stale. See `docs/learnings/skill-ship-bump-semver-silent-noop-without-jq.md`.
- **skill-edits-self-referential-build** (blocker) — editing forge's own skills has no automated tests, and the active plugin loads from the install cache (not the worktree), so a fresh session won't exercise repo edits without a dev-install. See `docs/learnings/blocker-skill-edits-self-referential-build.md`.

## [0.5.0] - 2026-05-04

### Learnings

- **spec-driven-build-clean-merge** (win) — Rigorous `/prd` → `/prd-refine` → `/build` pipeline produced 4 clean-merging sub-tasks with all acceptance criteria passing on first try. See `docs/learnings/win-spec-driven-build-clean-merge.md`.
- **feature-builder-cannot-commit** (blocker) — Worktree-isolated `feature-builder` agents are denied `git add` / `git commit` by default; parent session must commit on their behalf. See `docs/learnings/blocker-feature-builder-cannot-commit.md`.
- **skills-load-at-session-start** (blocker) — Claude Code caches skill contents at session start; mid-session edits to a skill do not hot-reload. See `docs/learnings/blocker-skills-load-at-session-start.md`.
- **ship-metadata-version-can-regress** (skill-quality) — In a multi-plugin marketplace, `metadata.version` can silently regress when the highest-versioned plugin is not in the ship's diff. Deferred in PR #6; fix before a second plugin ships. See `docs/learnings/skill-ship-metadata-version-can-regress.md`.

### Changed
- mark metadata.version regression and README single-source-of-truth as resolved in learnings
- restructure README to evergreen single-source-of-truth form

### Added
- bump-semver now rewrites README version line and derives marketplace metadata.version as max across plugins with SemVer pre-release awareness

## [0.4.0] - 2026-05-04

### Added

- `/forge:ship` Step 3e now handles Claude-plugin manifests — `bump-semver.sh` detects `plugins/*/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, bumps only the plugin(s) whose source files changed in the diff, and writes all three version fields (plugin.json `.version`, marketplace `metadata.version`, marketplace `plugins[].version`) atomically.
- `/forge:ship` Step 3e now rotates `CHANGELOG.md` — after a non-zero bump, invokes `update-changelog.sh --release <new>` to turn `[Unreleased]` into a dated version heading. The manifest bump(s) and changelog rotation are folded into a single `chore(release): bump to <new>` commit, removing the need for a manual release PR.
- `plugins/forge/skills/ship/scripts/__verify__/` — hand-rolled verification harness for `bump-semver.sh` covering the new Claude-plugin detection branch, the apply branch, and 5 end-to-end acceptance scenarios. See `__verify__/README.md` for how to run.

### Changed

- `bump-semver.sh` stdout contract extended with a `claude-plugin:N` manifest-summary token when the Claude-plugin detection branch fires. Single-file manifests (`package.json`, `Cargo.toml`, etc.) keep their existing output shape.
- `/forge:ship` Step 3e prose rewritten to describe the new two-branch flow and the non-fatal stderr notices from `update-changelog.sh --release` (missing CHANGELOG, missing `[Unreleased]`).

### Learnings

- **ship-bump-semver-misses-plugin-manifests** (skill-quality) — `/forge:ship` Step 3e does not recognize `plugin.json` / `marketplace.json`, so feature ships leave versions stale. See `docs/learnings/skill-ship-bump-semver-misses-plugin-manifests.md`.
- **ship-no-changelog-release-rotation** (skill-quality) — `/forge:ship` has no step that rotates `[Unreleased]` into a dated version heading; releases need a manual `update-changelog.sh --release` follow-up. See `docs/learnings/skill-ship-no-changelog-release-rotation.md`.

## [0.3.0-alpha] - 2026-05-04

### Added

- `code-reviewer` agent (`plugins/forge/agents/code-reviewer.md`) — reviews a pending diff for dead code, obvious bugs, style drift, missing tests, and readability wins; returns JSON findings with `auto` patches or `manual` flags. Separate from the scope-only `reviewer` agent used inside `/build`.
- `/forge:ship` **Step 0.5 — Code Review** gate — runs `code-reviewer` against the uncommitted diff, auto-applies safe patches, surfaces manual/`fail` findings via multi-choice, falls back cleanly when the agent is absent.
- `/forge:ship` **Step 8 — Sync learnings into CHANGELOG** — runs after Step 7 (capture) and appends a `### Learnings` subsection to `[Unreleased]` for learnings captured this session, linking each entry to its `docs/learnings/` file. Follow-on commit is pushed to the existing PR.
- `/forge:learn` **`win` learning type** — positive counterpart to `blocker`; captures approaches that worked with a `**What worked:**` replay note. Example in `references/types.md`.
- `/forge:learn retro [--days N]` mode — read-only "going right / going wrong / still being decided" digest that cross-references learnings with recent ships.
- Prior-learnings surfacing at entry of `/forge:prd`, `/forge:prd-refine`, and `/forge:build` — each reads `docs/learnings/INDEX.md` and surfaces relevant `convention`/`pattern`/`win`/`blocker` entries before asking the first question, closing the feedback loop from past runs.

### Changed

- `/forge:product-discovery` — user-facing questions rewritten for friendliness: plain language, multi-choice by default, one short question at a time, no framework jargon ("OST", "well-formed outcome", "riskiest assumption") in prompts. All 8 steps preserved. The embedded `/grill-me` delegation in Step 4 is replaced with a short inline pressure-test; `/grill-me` remains available as an opt-in.

### Learnings

- **skill-step-numbering-vs-data-deps** (blocker) — Workflow skills with numbered steps must have producer steps run before consumers. See `docs/learnings/blocker-skill-step-numbering-vs-data-deps.md`.
- **git-checkout-destroys-uncommitted-work** (blocker) — Never use `git checkout -- <files>` to revert an auto-applied patch on a dirty working tree; use `git apply -R` instead. See `docs/learnings/blocker-git-checkout-destroys-uncommitted-work.md`.
- **code-reviewer-gate-before-commit** (win) — The /ship Step 0.5 code-review gate caught two fail-severity bugs on day one. See `docs/learnings/win-code-reviewer-gate-before-commit.md`.

## [0.2.0-alpha] - 2026-05-01

### Added

- `/forge:security-review` skill — three-valued PASS/WARN/FAIL gate covering injection, authn/authz, secrets, crypto, dependency CVEs, input validation, and PII logging
- `/forge:fix` skill — bug-fix fast path enforcing reproduce-first discipline, root-cause investigation, minimal patch, and bisect-friendly two-commit output
- `secret-scan` PreToolUse hook (`plugins/forge/scripts/secret-scan.sh`) — blocks `git commit` when staged diff contains high-confidence secrets; `.secretscanignore` allowlist for false positives
- Ship helper scripts under `plugins/forge/skills/ship/scripts/` — `conventional-commit.sh` (strict subject validator, rejects `Co-Authored-By:`), `bump-semver.sh` (derives + applies semver bump from commit range), `update-changelog.sh` (Keep-a-Changelog append + release modes), `propose-commits.sh` (atomic-grouping heuristic)
- `plugins/forge/references/multi-choice.md` — canonical prompt-style reference; `/forge:discover`, `/forge:prd`, `/forge:grill-me`, `/forge:fix` now point at it
- `prd-refine` adds required **System Design** and **Threat Model Checklist** sections, with ADR guidance when a real tradeoff is made

### Changed

- `/forge:ship` gains a **Step 0 — Security Review** gate; WARN findings can be accepted and are appended to the PR body; FAIL aborts
- `/forge:ship` **Step 3 — Commit** now walks through atomic groupings, validates every message via `conventional-commit.sh`, applies the semver bump via `bump-semver.sh`, and routes changelog entries through `update-changelog.sh`
- `commit-conventions.md` documents the `Co-Authored-By:` ban

### Added

- Initial forge plugin under the mjolnir marketplace
- Ported skills, agents, hooks, scripts, and verifier from did-workflow under the forge brand
- GitHub-native command set (`gh` replaces `glab` in ship, build, learning-capturer, and related skills)
- Two-line statusline (`scripts/statusline.sh`) auto-applied via plugin `settings.json`

### Notes

- v0.1-alpha is a foundation release. Functional upgrades (atomic-commit `/ship`, `/fix`, `/security-review`, multi-choice prompts, broader stack coverage) land in subsequent milestones per `docs/superpowers/specs/2026-05-01-forge-plugin-design.md`.
