---
name: prd-refine
description: >
  Enriches a spec with technical detail. When given a spec created by /prd
  (business sections only), adds technical sections (API design, data model,
  implementation plan, test scenarios) directly onto the same file. Also works
  standalone — when no prior spec exists, generates a full spec from conversation.
  Use when a user says "refine this", "spec this out", "add technical detail",
  "prd-refine", "make this spec buildable", "add the implementation plan",
  "add API design", "add technical sections", or wants to prepare a spec for
  /build. Reads the repo's CLAUDE.md and existing code to ground technical
  decisions in the actual codebase. Waits for human approval before any code
  is written.
---

# PRD Refine — Technical Spec Generator

Add technical detail to a spec created by `/prd`, or produce a full spec from a
feature request. No code is written here — the goal is a document specific
enough that a developer (or subagent) can execute it without asking follow-up
questions. When enriching, the existing business content stays unchanged and
technical sections are appended.

## Step 1: Extract Feature Details

### Spec Resolution (from /prd output)

If `$ARGUMENTS` is provided, check if it resolves to a spec file created by `/prd`:

1. Try `docs/specs/$ARGUMENTS/spec.md`
2. Try `specs/$ARGUMENTS/spec.md`
3. Try `$ARGUMENTS` directly (if it's a path to a `spec*.md` file)

If a spec file is found that contains business sections but no technical
sections (created by `/prd`), read it and extract: feature name, ticket number,
scope, nature (bug/user-facing/technical), target user, goals, acceptance
criteria, business rules, and open questions. These become the feature details
for the rest of the workflow. Skip conversation extraction for any detail
already captured in the file.

The existing Acceptance Criteria (Gherkin from `/prd`) stay in place. This
skill adds technical sections (API design, data model, implementation plan,
test scenarios, etc.) directly onto the same file.

### Conversation Extraction (fallback)

If no PRD is found or no argument is provided, scan the conversation for:

- **Feature name** — a short descriptive name (kebab-case for file naming)
- **Ticket/issue number** — ask if not mentioned; accept `TBD` if unknown
- **Scope** — bug fix / small change (< 1 day) vs. larger feature
- **Nature** — user-facing (has an end user) vs. technical (refactor, infra, dependency upgrade, performance, security, migration, tech debt — no end-user story)
- **Affected areas** — backend, frontend, both, database changes

## Step 1.5: Design Interrogation Gate

If the scope is **larger feature** or key design decisions are unresolved, run
the `grill-me` skill on the feature before proceeding. This surfaces edge cases
and resolves design branches so the spec captures them rather than leaving them
as open questions.

Skip this step if a PRD was loaded (interrogation already happened during PRD
creation) or for bug fixes and small changes (< 1 day).

## Step 2: Prerequisites Gate

Before proceeding, confirm you have enough context:

- What the feature does and who it's for
- The scope (bug fix / small change or larger feature)
- Whether it affects backend, frontend, or both
- Whether it requires database/schema changes

If a PRD was loaded, most of these are already satisfied. The gate shifts to
verifying the PRD's acceptance criteria are unambiguous enough to ground
technical decisions. If any criteria are vague or conflicting, ask the user
for clarification.

If any of these is unclear, ask the user before loading context or writing anything.

## Step 3: Context Loading

1. Read this repo's `CLAUDE.md` to understand architecture, conventions, and file layout. If it has a `## Learnings` section, pay attention to `convention-` and `pattern-` rules relevant to the feature's domain — these shape the spec's API design, test scenarios, and implementation plan. When a rule references a file in `docs/learnings/`, read it if the feature touches that area.
2. Load any reference docs listed in `CLAUDE.md` under "Context Loading" or "Reference Docs"
   (data models, API references, component docs, shared constants). Skip if none listed.
3. Grep for similar existing implementations. Read one exemplar file in full — prefer the
   most recently modified file that matches the feature's stack layer (backend, frontend,
   or shared). Note the patterns to follow.

## Step 4: Choose Template

If a PRD was loaded, its nature/scope maps to spec templates:

| PRD Type                  | Spec Template(s)                                                                                                 |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Bug PRD                   | `${CLAUDE_SKILL_DIR}/references/template-simple.md`                                                              |
| Simple enhancement PRD    | `${CLAUDE_SKILL_DIR}/references/template-simple.md`                                                              |
| Feature PRD (user-facing) | `${CLAUDE_SKILL_DIR}/references/template-story.md`                                                               |
| Technical PRD             | `${CLAUDE_SKILL_DIR}/references/template-technical.md`                                                           |
| Epic PRD                  | `${CLAUDE_SKILL_DIR}/references/template-overview.md` + `template-story.md` or `template-technical.md` per story |

Without a PRD, determine template from conversation context:

| Scope                          | Template(s) to read                                                                                              |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| Bug fix / small change < 1 day | `${CLAUDE_SKILL_DIR}/references/template-simple.md`                                                              |
| Technical task (no end user)   | `${CLAUDE_SKILL_DIR}/references/template-technical.md`                                                           |
| Single user story              | `${CLAUDE_SKILL_DIR}/references/template-story.md`                                                               |
| Multiple stories (mixed)       | `${CLAUDE_SKILL_DIR}/references/template-overview.md` + `template-story.md` or `template-technical.md` per story |

Read the appropriate template file(s) before generating the spec. The template defines
the output format — fill in its sections with content specific to this feature.

**For multiple stories**, identify each distinct story first:

- Each story must deliver independent value and map to exactly one ticket
- User-facing stories: express as "As a [user], I want to [action] so that [benefit]" — use `template-story.md`
- Technical stories: use `template-technical.md` — do NOT force a user story format
- Generate one overview spec + one story spec per story

## Step 5: Fill the Template

### If enriching a `/prd` output (spec file already exists):

Edit the existing spec file(s) in `docs/specs/{ticket}-{name}/` in place. Do NOT
create new files — add technical sections directly onto the existing content.

For a **single spec** (`spec.md`): read the file, then append technical sections
after the existing business content.

For an **epic**: read the overview `spec.md` and each `spec-{story-slug}.md` listed
in the Story Index. Enrich each story file with technical sections. Update the
overview only if shared architecture notes or cross-story dependencies are needed.

**Technical sections to add** (use the corresponding spec template as a guide for
format — `template-story.md`, `template-technical.md`, or `template-simple.md`):

- **Functional Requirements** — validation rules, atomicity, idempotency
- **Permissions & Security** — scope, authorization, input validation
- **System Design** (required for larger features; skip for bug fixes / simple changes):
  - Components and their responsibilities (one short paragraph per component)
  - Interfaces — HTTP endpoints, events, DB schemas, shared contracts
  - Data flow diagram (mermaid `flowchart` or `sequenceDiagram`)
  - Tradeoffs considered — list 2+ alternatives with the chosen decision and why.
    If a genuine tradeoff was made, write an ADR to `docs/adr/NNN-<slug>.md`
    (next free number) and link it from this section.
- **Threat Model Checklist** (required; skip only for docs/chore-shaped specs):
  - **Data classification** — does this handle PII, secrets, or public data?
  - **Attack surface** — new endpoints, deserializers, file uploads, redirects?
  - **Authn / authz changes** — new roles, new middleware, new public routes?
  - **Dependency additions** — list new packages and their trust posture
  - Flag any item that warrants attention; otherwise write `N/A — <reason>`.
- **API Design** — endpoints, request/response with concrete examples, error table
- **Data Model & Migrations** — if applicable; delete if no DB changes
- **Architecture Notes** — new dependencies, integration points, exemplar files
- **Implementation Plan** — sub-tasks with INDEPENDENT/SEQUENTIAL labels, size estimates, file paths
- **Negative Constraints** — what must NOT be changed
- **Test Scenarios** — implementation-level detail: specific IDs, endpoints, DB fields, error codes. These complement the existing Acceptance Criteria (Gherkin from `/prd`), which stay as-is.
- **Verification** — backend tests, browser/UI testing, E2E test mapping (map each user-facing Key Scenario to an E2E test file and assign to a sub-task; backend-only scenarios stay as integration tests in Test Scenarios)

**Rules for enriching:**

- Do NOT modify, reorder, or remove existing business content (user story, acceptance
  criteria, scope, goals, business rules, success metrics). It was approved by the PO.
- Do NOT duplicate the Acceptance Criteria as "Key Scenarios" — they already exist.
- Add a `---` horizontal rule before the first technical section to visually separate
  business content from technical content.
- Full file paths for every file to create or modify.

### If no prior spec exists (fallback — conversation extraction):

Write spec file(s) to `docs/specs/{ticket}-{name}/` at the repo root, creating the
`docs/specs/` directory if it doesn't exist. Use just `{name}/` if there's no ticket number.

File naming:

- Single story: `spec.md`
- Multi-story: `spec.md` (overview) + `spec-{story-slug}.md` per story

Fill the full template as a complete document (both business and technical sections).

### Quality rules

Apply these **quality rules** in both modes:

- **No placeholders** — never leave `[TBD]`, `[placeholder]`, `TODO`, or `[Insert X]`
  markers (ticket IDs may be `TBD`)
- **Concrete examples** — use realistic values like `{"email": "user@example.com", "id": 42}`,
  never `{"email": "string"}`. At least 3 concrete data examples across the spec.
- **Specific errors** — every error must have a code and message:
  `400 INVALID_STATUS "Cannot check in a cancelled registration"`, not "return error"
- **Key Scenarios** — behavior-level Given/When/Then from the user's perspective.
  Read `${CLAUDE_SKILL_DIR}/references/bdd-format.md` for format rules.
- **Test Scenarios** — implementation-level detail: specific IDs, endpoints, DB fields,
  error codes. These are separate from Key Scenarios.
- **Delete unused sections** — if the feature has no DB changes, delete the Data Model
  section entirely. No empty stubs.
- **Full file paths** — list every file to create or modify with its full path.
- **E2E mapping** — if the project has an E2E framework (Playwright/Cypress config or e2e
  scripts in package.json), map each user-facing Key Scenario to an E2E test in the
  Verification section. Assign each to the sub-task that completes the user flow. Backend-only
  scenarios (pure API, no UI) are covered by Test Scenarios — do not map them to E2E.
  Delete the E2E Tests sub-section if no E2E framework exists. The `e2e-create`
  skill consumes this table downstream — be exhaustive here, because that skill
  will not invent scenarios beyond what you map.

Additional spec content (add where relevant):

**Negative Constraints** — list what must NOT be changed:

- Do NOT refactor [specific code]
- Do NOT modify [specific files outside scope]

**Multi-Repo Coordination** (if the feature spans multiple repos):

- API Contract: exact request/response shapes
- Build order: which repo first
- Stability gate: what must be stable before the next repo starts

## Step 6: Validate

Before presenting the spec, verify every item below. Fix any failures.

- [ ] No `[TBD]`, `[placeholder]`, `TODO`, or `[Insert X]` markers (ticket IDs may be TBD)
- [ ] At least 3 concrete data examples with realistic values
- [ ] All error messages have specific codes and text
- [ ] Key Scenarios use behavior-level language (user perspective, no DB fields or API endpoints) — story/overview specs only; skip for simple and technical specs
- [ ] Test Scenarios use implementation-level detail (specific IDs, endpoints, error codes)
- [ ] Optional sections deleted if not applicable — no empty stubs
- [ ] Every file to create/modify listed with full paths
- [ ] Verification section includes only applicable tiers (backend/browser/E2E)
- [ ] Each user-facing Key Scenario is mapped to an E2E test with an assigned sub-task (if E2E framework exists)
- [ ] Backend-only scenarios are NOT duplicated as E2E tests
- [ ] Each implementation sub-task has a size estimate
- [ ] Each implementation sub-task is labeled INDEPENDENT or SEQUENTIAL (required by `/build`)
- [ ] Open Questions resolved or explicitly deferred with rationale
- [ ] For multi-story: each story file has exactly one "As a..." statement (user-facing) or technical framing
- [ ] If enriching a `/prd` output: all original business content preserved unchanged
- [ ] If enriching a `/prd` output: technical sections added after `---` separator
- [ ] If enriching a `/prd` output: Test Scenarios complement (not duplicate) existing Acceptance Criteria
- [ ] System Design section present for larger features (components, interfaces, data flow, tradeoffs)
- [ ] Threat Model Checklist present (data classification, attack surface, authn/authz, dependencies); `N/A` allowed with reason
- [ ] ADR written and linked if a real tradeoff was made

Then STOP. Tell the user the path(s) of the spec file(s) written and ask for approval before any code is written.
