# Technical Spec Template

Use this template for **technical work that has no end-user story** — refactoring, infrastructure, dependency upgrades, performance optimization, security hardening, CI/CD changes, non-feature migrations, etc. Replaces the user story format with a problem/motivation framing.

```markdown
# [Task Name]

**Ticket:** [TICKET-123 or TBD]
**Type:** Refactor / Infrastructure / Dependency Upgrade / Performance / Security / Migration / Tech Debt
**Parent:** [spec.md](spec.md) ← link to overview spec (omit for standalone tasks)
**Execution:** [Parallel / Sequential — depends on {task name}]

## Motivation

[2-3 sentences: why this work needs to happen now. Frame in terms of risk, cost, or what it unblocks — not in terms of a user wanting something.]

**Current state:** [What exists today and why it's a problem]

**Desired state:** [What should be true after this work is done]

**Trigger:** [What prompted this work — incident, audit finding, blocked feature, tech debt threshold, upcoming deprecation, etc.]

## Scope

- **In scope:** [explicit list]
- **Out of scope:** [explicit list]

## Technical Goals

- [Goal 1 — measurable where possible, e.g., "reduce p95 latency from 800ms to under 200ms"]
- [Goal 2]
- [Goal 3]

## Success Criteria

- [Criterion 1 — how you know this work achieved its goal]
- [Criterion 2 — metric, benchmark, or observable property]

## Constraints & Risks

- **Backwards compatibility:** [Must maintain / can break with migration / N/A]
- **Downtime:** [Zero-downtime required / maintenance window acceptable / N/A]
- **Rollback plan:** [How to revert if something goes wrong]
- **Risks:** [What could go wrong and mitigations]

## Solution Design

[Describe the approach. For refactors, explain the before/after structure. For infra changes, describe the topology change. For upgrades, list breaking changes to address.]

### Changes

- `[file path]` — [what changes and why]
- `[file path]` — [what changes and why]

### Data Model & Migrations (Optional — delete if no DB/schema changes)

**Table: `[table_name]`**

| Field  | Type   | Constraints       | Description       |
| ------ | ------ | ----------------- | ----------------- |
| id     | uuid   | PK                | Unique identifier |
| field1 | string | Required, max 255 | [Purpose]         |

**Migration notes:**

- [Data backfill requirements]
- [Downtime considerations]

## Architecture Notes

- **New dependencies:** [packages/services needed, or "none"]
- **Dependencies & integration:** [affected features, shared state, breaking changes]

## Exemplar Files

- [Path to similar existing implementation] — [what pattern to follow]

## Implementation Plan

### Sub-tasks

**Task 1: [description]** — _small/medium/large_ (<100 / 100–300 / 300+ LOC)

- Files: `[path]`
- INDEPENDENT

**Task 2: [description]** — _small/medium/large_

- Files: `[path]`
- SEQUENTIAL (depends on Task 1)

### Negative Constraints

- Do NOT refactor [specific code outside scope]
- Do NOT modify [specific files outside scope]

## Test Scenarios

**Test 1: [Existing behavior preserved]**

- Setup: [specific state with realistic values]
- Action: [exact operation]
- Expected: [same behavior as before the change]

**Test 2: [New behavior or improvement validated]**

- Setup: [state]
- Action: [operation]
- Expected: [specific measurable outcome]

**Test 3: [Failure / rollback scenario]**

- Setup: [state that triggers failure path]
- Action: [operation]
- Expected: [graceful degradation or rollback behavior]

## Acceptance Criteria

- [ ] [Criterion — specific, testable]
- [ ] [Criterion — specific, testable]
- [ ] All existing tests still pass
- [ ] No type errors or lint warnings
- [ ] [Performance/security/infra-specific criterion if applicable]

## Verification

Run the verifier skill to confirm changes are clean.

### Backend Tests (if applicable)

List specific test files to create/modify and what each test covers.

### Manual Verification (if applicable)

- [ ] [Operational check — e.g., deploy to staging, verify metrics]
- [ ] [Edge case not covered by automation]

### E2E Tests (if E2E framework exists and changes affect user-facing flows — delete if not applicable)

Most technical tasks do not need E2E tests. Include only if the change
affects observable user behavior.

| Scenario                                   | Test file                            | Assigned sub-task |
| ------------------------------------------ | ------------------------------------ | ----------------- |
| [User-facing flow affected by this change] | `tests/e2e/[feature]-[flow].spec.ts` | Task [N]          |

## Open Questions

> Resolve all questions before implementation. Non-blocking questions may be deferred with rationale.

- [x] ~~[Question 1]~~ — **Resolved:** [Decision and rationale]
- [ ] [Question 2] — **Deferred (non-blocking):** [Why this doesn't block implementation]
```
