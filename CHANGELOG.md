# Changelog

All notable changes to the forge plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- `code-reviewer` agent (`plugins/forge/agents/code-reviewer.md`) — reviews a pending diff for dead code, obvious bugs, style drift, missing tests, and readability wins; returns JSON findings with `auto` patches or `manual` flags. Separate from the scope-only `reviewer` agent used inside `/build`.
- `/forge:ship` **Step 0.5 — Code Review** gate — runs `code-reviewer` against the uncommitted diff, auto-applies safe patches, surfaces manual/`fail` findings via multi-choice, falls back cleanly when the agent is absent.
- `/forge:ship` **Step 8 — Sync learnings into CHANGELOG** — runs after Step 7 (capture) and appends a `### Learnings` subsection to `[Unreleased]` for learnings captured this session, linking each entry to its `docs/learnings/` file. Follow-on commit is pushed to the existing PR.
- `/forge:learn` **`win` learning type** — positive counterpart to `blocker`; captures approaches that worked with a `**What worked:**` replay note. Example in `references/types.md`.
- `/forge:learn retro [--days N]` mode — read-only "going right / going wrong / still being decided" digest that cross-references learnings with recent ships.
- Prior-learnings surfacing at entry of `/forge:prd`, `/forge:prd-refine`, and `/forge:build` — each reads `docs/learnings/INDEX.md` and surfaces relevant `convention`/`pattern`/`win`/`blocker` entries before asking the first question, closing the feedback loop from past runs.

### Changed

- `/forge:product-discovery` — user-facing questions rewritten for friendliness: plain language, multi-choice by default, one short question at a time, no framework jargon ("OST", "well-formed outcome", "riskiest assumption") in prompts. All 8 steps preserved. The embedded `/grill-me` delegation in Step 4 is replaced with a short inline pressure-test; `/grill-me` remains available as an opt-in.

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
