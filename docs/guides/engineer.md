# Engineer Guide

This guide covers the skills engineers use to refine specs, build features, run tests, and document architecture.

## Your Workflow

```
/prd-refine my-feature → /build my-feature → /doc-architect
```

1. Receive an approved PRD from a product owner
2. Run `/prd-refine` to add technical detail (API design, data model, implementation plan)
3. Run `/build` to execute the spec end-to-end
4. Run `/doc-architect` to update architecture docs

For manual development (without a full spec), use `/tdd` to code, then `/ship` to get it merged:

```
/tdd → /ship
```

You can also use `/verifier` and `/e2e` independently at any point.

---

## /prd-refine — Technical Spec Enrichment

Enriches a PRD with technical detail — API design, data model, implementation plan, test scenarios. The original business content stays unchanged; technical sections are appended.

### When to Use

- After a product owner approves a `/prd` output and hands it off
- When you need to add implementation-level detail to a spec
- Standalone: when no prior PRD exists, generates a full spec from conversation

### Usage

```
/prd-refine <spec-name>
```

Resolves the spec by checking:

1. `docs/specs/<spec-name>/spec.md`
2. The argument as a direct path

Examples:

```
/prd-refine add-user-notifications
/prd-refine PROJ-123-checkout-flow
/prd-refine @docs/specs/add-user-notification
```

### How It Works

1. **Resolve spec** — Finds the PRD file and extracts business context
2. **Design interrogation** — For larger features, runs `/grill-me` on technical design decisions (skipped if PRD already went through interrogation, or for bug fixes)
3. **Context loading** — Reads `CLAUDE.md`, reference docs, and exemplar files from the codebase
4. **Template selection** — Maps PRD type to spec template (simple, story, technical, or overview + stories)
5. **Enrich** — Appends technical sections after a `---` separator:
   - Functional requirements (validation, atomicity, idempotency)
   - Permissions and security
   - API design with concrete request/response examples
   - Data model and migrations (if applicable)
   - Architecture notes and exemplar files
   - Implementation plan with INDEPENDENT/SEQUENTIAL task labels
   - Negative constraints (what must NOT change)
   - Test scenarios (implementation-level detail)
   - Verification tiers (backend, browser, E2E)
6. **Validate** — Checks completeness, concrete examples, full file paths

### For Epics

Reads the overview and each story file from the Story Index. Enriches each story with technical sections individually. Updates the overview only if shared architecture notes are needed.

### Tips

- The business content from `/prd` is preserved unchanged — don't worry about it being modified
- Every file to create or modify is listed with full paths in the implementation plan
- Sub-tasks are labeled INDEPENDENT or SEQUENTIAL — this is what `/build` uses for parallelization
- Run this before `/build` — the build skill expects a technically complete spec

---

## /build — Spec Executor

Executes an approved spec end-to-end across five phases: context loading, task decomposition, parallel execution, verification, and MR creation.

### When to Use

- After a spec has been refined with `/prd-refine` and approved
- When you want to implement a feature from spec to merge request automatically

### Usage

```
/build <spec-name>
```

Resolves the spec by checking:

1. `docs/specs/<spec-name>/spec.md`
2. `specs/<spec-name>/spec.md`
3. The argument as a direct path

### How It Works

#### Phase 1 — Context Loading

Reads `CLAUDE.md`, the spec file, architecture decision files, exemplar files, and existing tests. Hard limit: 15 files.

#### Phase 2 — Task Decomposition

Reads the implementation plan from the spec:

- **INDEPENDENT** tasks → launched as parallel `feature-builder` agents
- **SEQUENTIAL** tasks → queued and run in order

Asks you which branch to use as base, then creates `feature/{spec-name}` from it.

#### Phase 3 — Execution

Spawns `feature-builder` agents, each working in an isolated worktree on their sub-task. Each agent:

- Follows TDD (RED → GREEN per acceptance criterion)
- Makes conventional commits (`feat(scope): description`)
- Runs verifier and E2E tests
- Sequential task branches are merged into the feature branch immediately
- Independent task branches are collected for Phase 3.5

#### Phase 3.5 — Branch Merge

Merges all independent task branches into `feature/{spec-name}`. On merge conflict: writes `BLOCKED.md` and stops (no auto-resolution).

#### Phase 4 — Verification

1. Runs `/verifier` on the merged feature branch
2. Checks every acceptance criterion from the spec
3. Runs `/e2e` for the full E2E suite
4. Spawns targeted fix agents for failures (max 1 retry each)
5. If still failing after retries: writes `BLOCKED.md`

#### Phase 5 — MR

Creates a merge request targeting the base branch. Includes: spec link, summary, files changed, how to test, acceptance checklist.

### Tips

- Have an approved, technically complete spec before running `/build`
- Make sure the base branch is clean and up to date
- Watch for `BLOCKED.md` — it means something needs manual intervention
- The base branch is read-only during the entire build process
- Merge conflicts are never auto-resolved — this is intentional

---

## /ship — Branch, Commit, Push, MR

Ships changes from your working directory to a GitLab merge request in one command. Detects where you are in the git workflow and picks up from the right step.

### When to Use

- After manual coding or `/tdd` — when you need to get changes into a merge request
- When you want to commit and push with consistent conventions
- When you already have a branch pushed and just need an MR
- As a lightweight alternative to `/build` Phase 5 when you don't have a spec

### Usage

```
/ship
/ship PROJ-123
/ship PROJ-123 add user notifications
```

Optional arguments: ticket ID (e.g., `PROJ-123`) and/or a description.

### How It Works

The skill detects your current git state and runs only the steps you need:

| Starting state                             | Steps executed              |
| ------------------------------------------ | --------------------------- |
| On `main` with uncommitted changes         | Branch → Commit → Push → MR |
| On feature branch with uncommitted changes | Commit → Push → MR          |
| On feature branch with unpushed commits    | Push → MR                   |
| On feature branch, already pushed          | MR only                     |

#### Branch Creation

- **Never commits to protected branches** (`main`, `master`, `develop`)
- Prefixes aligned to commit types: `feature/`, `fix/`, `chore/`, `refactor/`, `docs/`, `test/`
- Format: `{prefix}{ticket-id}-{description}` or `{prefix}{description}`
- Example: `feature/PROJ-123-add-user-notifications`

#### Commit

- Follows [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): imperative description`
- Auto-detects type and scope from the diff
- Adds `Refs: TICKET-123` footer when a ticket ID is known
- Handles the changelog guard automatically (updates and stages `CHANGELOG.md`)

#### MR

- Creates via `glab mr create` targeting the base branch
- Auto-generates title from commit history
- Fills in summary, ticket reference, changes, how to test, and review checklist
- Pass "draft" to create a draft MR

### Tips

- Run `/verifier` before `/ship` to catch issues early
- If `glab` is not authenticated, you'll be prompted to run `glab auth login`
- The skill never mentions AI tools in commits or MRs
- For spec-driven work, prefer `/build` which handles the full pipeline

---

## /tdd — Test-Driven Development

Enforces red-green-refactor TDD discipline with vertical slicing. Used automatically by `feature-builder` agents during `/build`, but also available for manual development.

### When to Use

- When building a feature or fixing a bug test-first
- When you want guided TDD discipline
- During manual development outside of `/build`

### Usage

```
/tdd
```

Then describe what you're building in the conversation.

### How It Works

1. **Planning** — Confirm interface changes and which behaviors to test with the user
2. **Tracer bullet** — Write ONE test for ONE behavior, make it pass
3. **Incremental loop** — For each remaining behavior: write test (RED) → minimal code (GREEN) → repeat
4. **Refactor** — After all tests pass, look for extraction, SOLID, and deep module opportunities

### Key Principles

- **Vertical slicing**: One test → one implementation → repeat. Never write all tests first.
- **Test behavior, not implementation**: Tests should survive internal refactors
- **Public interfaces only**: Test through the API users actually call
- **Never refactor while RED**: Get to GREEN first

### Stack-Specific Patterns

| Stack           | Runner                | Key Rules                                                           |
| --------------- | --------------------- | ------------------------------------------------------------------- |
| TypeScript/Node | Jest or Vitest        | `async/await` in tests; mock at boundaries only                     |
| React           | React Testing Library | Query by what users see (`getByRole`, `getByText`); use `userEvent` |
| Python          | pytest                | Function-scoped fixtures; `mocker.patch` at boundaries              |
| Java            | JUnit 5               | `@SpringBootTest` for integration; Mockito at external seams only   |

### Tips

- Confirm with the user which behaviors matter most — you can't test everything
- Integration-style tests (real code paths through public APIs) are preferred over unit tests with mocks
- A good test reads like a specification: "user can checkout with valid cart"
- If a test breaks on refactor but behavior hasn't changed, the test was testing implementation

---

## /verifier — Stack-Aware Verification

Runs format, lint, type check, and tests on changed files. Auto-detects the project stack.

### When to Use

- After implementing a feature or fixing a bug
- Before committing or marking a task done
- Anytime you want to confirm your changes are clean

### Usage

```
/verifier
```

Also runs automatically via the `stop-verify` hook when any agent task completes.

### How It Works

Runs a single script that:

1. Detects the project stack (Node/Jest, Node/Vitest, Python, Java/Gradle, Java/Maven)
2. Runs the appropriate format, lint, type check, and test commands
3. Reports the result

### Results

- **PASS** — Changes are clean. Proceed.
- **FAIL** — Output tells you exactly what broke (`TYPE FAIL:`, `LINT FAIL:`, `TEST FAIL:`). Fix and re-run. You get 2 attempts.
- **FAIL after 2 attempts** — Writes `BLOCKED.md` with the error details and stops.

### Why Run Manually?

The `stop-verify` hook runs automatically, but it triggers _after_ the agent loop ends. Running `/verifier` yourself during the task lets you catch and fix issues in the same session.

---

## /e2e — E2E Test Runner

Detects the project's E2E framework, runs the full suite, and reports the outcome. Does not attempt to fix failures.

### When to Use

- After writing E2E tests
- When you need to validate end-to-end flows
- Also runs automatically during `/build` Phase 4

### Usage

```
/e2e
```

### Framework Detection

Checks in order:

1. `playwright.config.*` → Playwright
2. `cypress.config.*` or `cypress/` → Cypress
3. `package.json` scripts containing `e2e` → npm script
4. `e2e/` or `tests/e2e/` directory → inferred from contents

### Results

- **PASS** — All tests passed, with count
- **FAIL** — Lists failing tests with failure reasons, plus last 50 lines of output
- **ERROR** — Suite couldn't run (missing deps, config error, port conflict). Includes suggested fix
- **NO_E2E** — No E2E framework detected. Skipped

### Constraints

- Does NOT fix failing tests — report only
- Does NOT install missing dependencies
- Does NOT start servers or services
- 2-minute timeout

---

## /doc-architect — Architecture Documentation

Generates or incrementally updates `docs/architecture.md` with Mermaid diagrams. Works on any repo.

### When to Use

- After implementing a feature (especially after `/build`)
- When onboarding to a new repo
- When architecture has changed and docs are stale
- To generate initial architecture documentation

### Usage

```
/doc-architect
/doc-architect data-layer      # Focus on a specific area
```

### How It Works

1. **Detect mode** — Create (no existing doc) or Update (preserves unchanged sections)
2. **Context loading** — Reads `CLAUDE.md`, manifest files, directory structure, entry points (max 20 files)
3. **Generate sections**:
   - **System Overview** — What the system does, component diagram (Mermaid)
   - **Data Flow** — Primary data paths, sequence diagram (Mermaid)
   - **Directory Structure** — Module boundaries, dependency diagram (Mermaid)
   - **Tech Stack** — Languages, frameworks, integration points diagram (Mermaid)
   - **Key Patterns** — Architectural patterns, naming conventions, error handling
   - **Configuration** — Environment variables and config files
4. **Flag companions** — Suggests companion docs for sections that are too deep (e.g., `docs/data-model.md`, `docs/api-reference.md`)

### Tips

- Run after every significant feature — keeps docs in sync with code
- In update mode, only changed sections are rewritten
- At least 4 Mermaid diagrams are generated (component, sequence, module boundary, integration)
- Pass an argument to focus on a specific area of the codebase
