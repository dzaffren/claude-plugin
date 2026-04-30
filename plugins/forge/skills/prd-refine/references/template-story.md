# Story Spec Template

Use this template for **individual user story specs**. Each file must contain exactly ONE "As a..." user story. This maps 1:1 to a ticket.

````markdown
# [Story Name]

**Ticket:** [TICKET-123 or TBD]
**Parent:** [spec.md](spec.md) ← link to overview spec (omit for standalone single-story features)
**Execution:** [Parallel / Sequential — depends on {story name}]

## User Story

As a [user type], I want to [action] so that [benefit].

## Scope

- **In scope:** [explicit list]
- **Out of scope:** [explicit list]

## Key Scenarios

> Write scenarios from the **user's perspective** — describe what they see and do, not API calls, DB fields, or implementation IDs. See `references/bdd-format.md` for full Gherkin rules.

### Scenario: [Happy path description]

```gherkin
Given [precondition in user-visible terms]
When [user action]
Then [observable outcome the user can see]
  And [additional observable outcome]
```

### Scenario: [Error/edge case description]

```gherkin
Given [precondition causing the edge case]
When [user action]
Then [user-visible error or feedback]
```

### Scenario Outline: [Group of similar cases that differ only by input]

```gherkin
Given [precondition with <variable>]
When [user action with <input>]
Then [observable outcome with <expected>]

Examples:
  | variable | input  | expected |
  | value1   | inputA | outcome1 |
  | value2   | inputB | outcome2 |
```

## Functional Requirements

- **[Category]:** [Specific requirement — use "must" not "should"]
- **Atomicity:** All changes in a single transaction; rollback on failure
- **Idempotency:** Repeated calls must not cause duplicate effects

### Validation & Business Rules

- [Rule 1 with specific values/constraints and error if violated]
- [Rule 2 with specific values/constraints and error if violated]

## Permissions & Security

- **Scope:** [Public API / Admin API / Internal only]
- **Authorization:** [Role/permission required]
- **Input validation:** [Key sanitization rules, max lengths]

## API Design

### `[METHOD] /api/path/to/endpoint/:param`

**Request:**

```json
{
  "field1": "example-value",
  "field2": 42
}
```

**Response (200):**

```json
{
  "id": 123,
  "status": "completed",
  "updated_at": "2025-12-01T10:30:00Z"
}
```

**Errors:**
| Status | Code | Condition |
|--------|------|-----------|
| 400 | `ERROR_CODE` | [When this occurs] |
| 403 | `FORBIDDEN` | [When this occurs] |
| 404 | `NOT_FOUND` | [When this occurs] |

## Data Model & Migrations (Optional — delete if no DB changes)

### New/Modified Tables

**Table: `[table_name]`**

| Field  | Type   | Constraints       | Description       |
| ------ | ------ | ----------------- | ----------------- |
| id     | uuid   | PK                | Unique identifier |
| field1 | string | Required, max 255 | [Purpose]         |

### Migration Notes

- [Data backfill requirements]
- [Downtime considerations]

## UI/Frontend Requirements (Optional — delete if backend-only)

### Components

**[ComponentName]** — `src/components/[path]/[Name].tsx`

- **Type:** New / Modify existing
- **Purpose:** [What it does]
- **Props:**
  ```typescript
  interface Props {
    prop1: string;
    prop2?: number;
  }
  ```

### User Interactions

- [Action] → [What happens]

### States

- **Loading:** [What to show]
- **Empty:** [What to show when no data]
- **Error:** [How to display errors]

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

- Do NOT refactor [specific code]
- Do NOT modify [specific files outside scope]

## Test Scenarios

**Test 1: [Happy path]**

- Setup: [specific state with realistic values]
- Action: [exact operation, e.g., POST /api/v1/orders/123/confirm]
- Expected: [specific outcome, e.g., returns 200, status changes to "confirmed"]

**Test 2: [Error scenario]**

- Setup: [invalid state]
- Action: [operation]
- Expected: Error `ERROR_CODE` with message "specific message", no DB changes

**Test 3: [Idempotency]** (if applicable)

- Setup: [state]
- Action: Call operation twice
- Expected: First succeeds, second returns error, no duplicate effects

**Test 4: [Transaction rollback]** (if applicable)

- Setup: [state], mock [dependency] to fail
- Action: [operation]
- Expected: Fails with [error], all entities remain in original state

## Acceptance Criteria

- [ ] API returns expected responses for all test scenarios
- [ ] Permissions enforced correctly
- [ ] Error messages are clear and actionable
- [ ] No type errors or lint warnings
- [ ] [Story-specific criterion]

## Verification

Run the verifier skill to confirm changes are clean.

### Backend API Tests (if backend changes)

List specific test files to create/modify and what each test covers.
Reference the repo's existing test patterns from CLAUDE.md or exemplar files.

### Browser/UI Testing (if frontend changes)

Structured steps to verify UI behavior:

- Credentials & URL for test environment
- Setup steps (login, navigation)
- Numbered test steps with action + expected result
- Mobile viewport tests if applicable

### E2E Tests (if E2E framework exists — delete if not applicable)

Each Key Scenario that involves a user-facing flow maps to an E2E test.
Backend-only scenarios (pure API, no UI) are covered by integration tests
in the Test Scenarios section above — do not duplicate them here.

| Key Scenario                       | Test file                            | Assigned sub-task |
| ---------------------------------- | ------------------------------------ | ----------------- |
| [Scenario name from Key Scenarios] | `tests/e2e/[feature]-[flow].spec.ts` | Task [N]          |
| [Scenario name]                    | `tests/e2e/[feature]-[flow].spec.ts` | Task [N]          |

**Locator strategies:** [key selectors, data-testid attributes, or ARIA roles
used across tests — list once here, not per test]

## Multi-Repo Coordination (if applicable)

- **API Contract:** [exact request/response shapes]
- **Build order:** [which repo first]
- **Stability gate:** [what must be stable before next repo starts]

## Open Questions

> Resolve all questions before implementation. Non-blocking questions may be deferred with rationale.

- [x] ~~[Question 1]~~ — **Resolved:** [Decision and rationale]
- [ ] [Question 2] — **Deferred (non-blocking):** [Why this doesn't block implementation]
````
