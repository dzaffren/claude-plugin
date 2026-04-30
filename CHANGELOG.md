# Changelog

All notable changes to the did-workflow plugin are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [1.3.0] - 2026-04-28

### Added

- `e2e-create` skill — authors end-to-end tests in the project's existing framework (Playwright, Cypress, or other). Stack-agnostic: detects the framework, reads an exemplar test, sources scenarios from the spec's Verification > E2E Tests table (or caller description when no spec), and places tests where they already live. Does NOT install frameworks, mock internal services, or run the suite — that stays with `/e2e`.
- `learn` skill — per-repo learning capture. Writes typed learnings (convention, blocker, pattern, skill-quality) to `docs/learnings/` with `Why:` / `How to apply:` bodies. Modes: capture (default, with dedupe against the existing index), update (merges near-duplicates), audit (read-only list), remove (strips file + index line + CLAUDE.md bullet). Syncs high-confidence rules (user said "always" / "never" / "from now on") to the repo's CLAUDE.md `## Learnings` section.
- `learning-capturer` agent — runs at the end of `/build` and (optionally) `/ship`. Reads the session's diff, verifier output, and user corrections; proposes 0–N learning candidates for user approval; hands approved candidates to the `learn` skill for persistence. Silent when nothing novel happened — no approval prompts on quiet runs.

### Changed

- `build` skill — Phase 1 now reads `## Learnings` in CLAUDE.md and drills into `docs/learnings/` for rules relevant to the spec. Phase 6 (new) invokes `learning-capturer` at end of run.
- `ship` skill — Step 7a (new, optional) invokes `learning-capturer` post-ship. Step 7b (new, opt-in via `/ship --learn-from-comments`) fetches MR review comments via `glab api`, filters by learn-markers (`#learn`, "next time", "going forward", "always", "never"), and feeds matches through `learning-capturer` for approval.
- `prd` and `prd-refine` skills — context-loading step now scans `## Learnings` in CLAUDE.md for `convention-` and `pattern-` rules relevant to the feature domain.
- `feature-builder` agent — reads relevant learning files before starting a sub-task; updated to invoke `e2e-create` for authoring (replacing the inline E2E authoring guidance from 1.2.x) and `e2e` for running.
- `prd-refine` skill — E2E mapping rule now notes that the table is the source of truth for `e2e-create`, so it must be exhaustive: `e2e-create` does not invent scenarios beyond the table.
- `plugin.json` — registered new `e2e-create`, `learn` skills and `learning-capturer` agent (the `e2e-create` skill was authored earlier but had been missing from the registration).

### Docs

- `README.md` — added `e2e-create`, `learn`, and `learning-capturer` to the Plugin Contents tables; new "Per-Repo Learnings Contract" section documents the `docs/learnings/` layout and the boundary between per-repo learnings and personal auto-memory.
- README quickstart — updated installation steps to use `/marketplace` UI flow instead of manual `settings.json` edits; added SSH key setup and port configuration guide for GitLab access.
- README quickstart — corrected `/plugin` command (was `/marketplace`), added navigation path for adding marketplace, replaced manual git-pull update workaround with UI-based auto-update and force-update steps.

## [1.2.2] - 2026-04-23

### Changed

- `build` skill — branch prefix is now derived from the spec's `**Type:**` field instead of always using `feature/`. Mapping: Bug/Bug Fix → `fix/`, Refactor → `refactor/`, Infrastructure/Dependency Upgrade/Migration/Tech Debt → `chore/`, Performance/Security → `fix/`, everything else → `feature/`. For `Technical — [subtype]` specs, the subtype is matched.
- `build` skill — renamed internal variable `{feature-branch}` to `{build-branch}` throughout for consistency with the new prefix-agnostic naming.

## [1.2.1] - 2026-04-16

### Added

- ADR-001: Stacked PRs for Build Skill (`docs/adr/001-stacked-prs-for-build-skill.md`) — documents four options (single MR, stacked gates, post-merge MRs, stacked + auto-merge) for how `/build` should raise MRs when specs have multiple stories. Pending team decision.

### Changed

- `prd-refine` skill — Verification section now requires an E2E test mapping table: each user-facing Key Scenario maps to a test file and an assigned sub-task. Backend-only scenarios stay as integration tests; the E2E sub-section is deleted if no E2E framework exists.
- `template-story.md` — E2E Tests section redesigned: replaced loose bullet list with a structured table (Key Scenario | Test file | Assigned sub-task) and a single locator strategies block.
- `template-technical.md` — Added E2E Tests sub-section to Verification with the same table format; includes a note that most technical tasks do not need E2E tests.
- `build` skill — When spawning `feature-builder` subagents, now passes E2E test assignments from the spec's Verification table (scenario name, test file path, Given/When/Then). Added cross-check step to confirm every mapped scenario has a corresponding test file that was created and passed.
- `feature-builder` agent — Step 5 (E2E tests) is now spec-driven: checks the spec's E2E Tests table for assigned scenarios and implements them; falls back to judgment-based approach only when no table or assignment exists.

## [1.2.0] - 2026-04-10

### Added

- PRD skill (`skills/prd`) — business-focused product requirements generation with grill-me interrogation, template selection (bug, simple, feature, technical, epic), and prd-story-writer agents for epics. Outputs to `docs/specs/`.
- PRD Refine skill (`skills/prd-refine`) — enriches PRD with technical detail: API design, data model, implementation plan, test scenarios. Works standalone when no prior PRD exists.
- Ship skill (`skills/ship`) — lightweight branch → commit → push → MR workflow via `/ship`. Detects git state and picks up from the right step. Includes branch naming conventions, conventional commit format, and MR template references.
- PRD Story Writer agent (`agents/prd-story-writer.md`) — writes individual story PRDs for multi-story epics, spawned by `/prd` in parallel
- User guides: [Engineer Guide](docs/guides/engineer.md) and [Product Owner Guide](docs/guides/product-owner.md)
- Product Discovery skill (`skills/product-discovery`) — structured discovery using the Opportunity Solution Tree (OST) framework, upstream of `/prd`. Guides users from fuzzy ideas to validated opportunities through 8 steps: capture starting signal, frame desired outcome, discover opportunities, interrogate via grill-me, prioritize and select, brainstorm solutions and assumptions, build Mermaid OST diagram, write discovery brief and hand off. Supports three entry modes (vague idea, specific problem, clear outcome) and pause/resume across sessions via `status: in-progress` briefs with action items. Outputs to `docs/discovery/{name}/brief.md`.
- OST framework reference (`references/ost-guide.md`) and discovery brief template (`references/template-brief.md`) with Solution Candidates → PRD linkage
- Evals for prd, prd-refine, ship, product-discovery, and grill-me skills
- README: workflow diagram (Mermaid) with Discovery Phase, expanded skills/agents/hooks tables, quickstart updates
- PRD Jira integration (Step 8, optional) — after writing the PRD, offers to create Jira issues via Atlassian MCP. Creates the correct issue type per PRD type (Bug, Story, Epic + Stories). Updates spec files in-place with real ticket keys and renames the spec directory if it was created with a `TBD` prefix.
- POC skill (`skills/poc`) — generates a clickable HTML/CSS/JS prototype from a discovery brief or PRD. Supports static, interactive, and simulated-flow interactivity levels. Uses Tailwind CDN, realistic mock data, and outputs self-contained files to `docs/poc/{name}/`. Designed for two moments: after `/discover` (validate solution direction) and after `/prd` (validate UX before engineering starts).

### Changed

- Plugin version bumped to 1.2.0
- PRD skill (`skills/prd`) — Step 3 Context Loading now checks `docs/discovery/` for existing discovery briefs and pre-loads outcome, opportunity, and solution context. Adds discovery brief backlink in PRD output for traceability. Solution candidates from discovery guide epic story identification.
- Grill-me skill (`skills/grill-me`) — full rewrite with structured 5-step interview process: survey decision branches, walk each branch one question at a time, maintain a running decisions log, cross-cutting pressure-test, and produce a wrap-up summary. Each question now includes why it matters and a recommended answer. Domain-adaptive: product owner interviews stay strictly product/business-focused; technical design interviews stay in engineering territory.
- README restructured with full workflow documentation, role-based user guides, `/ship` lightweight path and Discovery Phase in diagram
- Product Owner Guide: add `/discover` section, update workflow to start with discovery, note discovery brief auto-loading in `/prd`
- Product Owner Guide: add `/poc` section with interactivity levels table, when-to-use guidance (after `/discover` and after `/prd`), and updated workflow diagram showing both optional `/poc` entry points
- Build skill Phase 1 now extracts the ticket ID from `**Ticket:**` in the spec and saves it as `{ticket}`.
- Build skill Phase 2 uses ticket-aware branch naming: reads `branch-conventions.md` and creates `feature/{ticket}-{spec-name}` when a ticket is present, falling back to `feature/{spec-name}`. Introduces `{feature-branch}` variable used consistently throughout Phases 3, 3.5, and 5.
- Build skill Phase 5 replaced inline MR creation with a delegation to the `ship` skill — passes `{ticket}` so ship can produce the MR following project conventions.

### Removed

- Spec skill (`skills/spec`) — replaced by separate `prd` (business) and `prd-refine` (technical) skills for clearer separation of concerns. Templates moved to `prd-refine/references/`.

## [1.1.6] - 2026-04-07

### Fixed

- Remove redundant `hooks` field from `plugin.json` — `hooks/hooks.json` is auto-loaded by Claude Code and re-declaring it caused a duplicate hooks error on install

### Changed

- Conventions doc: clarify that `hooks/hooks.json` is auto-loaded; `hooks` field in `plugin.json` is only for additional files at non-standard paths

## [1.1.5] - 2026-04-07

### Added

- E2E skill (`skills/e2e`) replacing the `e2e-runner` agent — callable by both feature-builder and build skill Phase 4
- Feature-builder now invokes the `e2e` skill after writing E2E tests to validate them within the worktree before handoff
- Register `grill-me` and `e2e` skills in plugin.json
- Wire `hooks/hooks.json` into plugin.json so changelog guard, block-dangerous, and stop-verify hooks are loaded

### Changed

- Feature-builder commits after each acceptance criterion goes GREEN (not once at the end)
- Commit messages follow conventional commit format: `type(scope): imperative description` (max 72 chars)
- Refactor step commits with `refactor(scope): {what was improved}` if changes were made
- Build skill Phase 4 uses `e2e` skill instead of `e2e-runner` agent

### Removed

- `agents/e2e-runner.md` — replaced by `skills/e2e/SKILL.md`

## [1.1.4] - 2026-04-06

### Added

- Technical spec template (`template-technical.md`) for work with no end-user story — refactors, infra, dependency upgrades, performance, security, migrations
- Spec skill routing and detection for technical vs. user-facing work
- E2E runner integration in build skill Phase 4 verification (NO_E2E / PASS / FAIL / ERROR handling)

### Changed

- BDD format reference: enforce single Given/When/Then per block with `And` for continuation — no repeated keywords
- BDD format reference: added bad/good example pair illustrating the rule
- Build skill: create feature branch in Phase 2 (before sub-tasks), base branch is now read-only
- Build skill: sequential task branches merge into feature branch immediately during Phase 3, so dependent tasks inherit prior changes
- Build skill: Phase 3.5 now only merges independent task branches (sequential already merged)

## [1.1.2] - 2025-03-21

### Fixed

- Prompt user for base branch before spawning worktrees in build skill

### Changed

- Documented manual update workaround

## [1.1.1] - 2025-03-20

### Fixed

- Use SSH URL in marketplace.json to avoid authentication prompts on update
- Use git-subdir source in marketplace.json for remote plugin install support
- Register hooks in plugin.json and sync version
- Move spec output path to `docs/specs/` and update build skill resolution
- Remove redundant hooks field from plugin.json

### Added

- Phase 3.5 branch collection and merge to build skill

## [1.1.0] - 2025-03-19

### Added

- TDD skill for test-driven development workflow
- Grill-me skill for design interrogation
- Spec interrogation gate (Step 1.5) before proceeding to larger features

## [1.0.0] - 2025-03-18

### Added

- Initial did-workflow plugin scaffold
- Spec skill with simple, story, and overview templates
- Build skill for parallel worktree-based feature execution
- Reviewer agent for scope-checking diffs
- Feature-builder agent for isolated sub-task implementation
- BDD format reference for Gherkin scenarios
- Marketplace configuration for GitLab-hosted plugin install
