# Simple Spec Template

Use this template for bug fixes and small changes (< 1 day).

````markdown
# [Feature Name]

**Type:** Bug Fix / Enhancement / New Feature
**Auth:** [public / requires X permission]

[2-3 sentences: what is this change, what problem does it solve, who is affected]

## Problem

**Current behavior:** [What happens now]

**Desired behavior:** [What should happen]

**Reproduction steps** (for bugs):
1. [Step 1]
2. [Step 2]
- Expected: [what should happen]
- Actual: [what actually happens]

## Scope

- **In scope:** [explicit list]
- **Out of scope:** [explicit list]

## Requirements

- [ ] [Requirement 1]
- [ ] [Requirement 2]
- [ ] [Requirement 3]

## Solution

**Changes:**
- `[file path]` — [what to change]
- `[file path]` — [what to change]

**API changes** (if any):

`[METHOD] /api/path` — [what changes in request/response]

**New dependencies** (if any): [packages/services needed, or "none"]

**Dependencies & integration:** [affected features, shared state, breaking changes]

**New error messages** (if any):
- `ERROR_CODE`: "Message" — when [condition]

## Test Cases

**Test 1: [Happy path]**
- Setup: [state]
- Action: [what to do]
- Expected: [outcome]

**Test 2: [Edge case]**
- Setup: [state]
- Action: [what to do]
- Expected: [outcome]

**Test 3: [Error scenario]**
- Setup: [state]
- Action: [what to do]
- Expected: [error behavior]

## Acceptance Criteria

- [ ] [Criterion 1 — specific, testable]
- [ ] [Criterion 2 — specific, testable]
- [ ] All existing tests still pass
- [ ] No type errors or lint warnings

## Verification

Run the verifier skill to confirm changes are clean.

### Backend tests (if backend changes)
- [ ] `[test command matching changed files]` passes

### Manual (human in the loop)
- [ ] [Visual or UX check only a human can confirm]
- [ ] [Edge case not covered by automation]

## Open Questions

> Resolve all questions before implementation. Non-blocking questions may be deferred with rationale.

- [x] ~~[Question]~~ — **Resolved:** [Decision]
- [ ] [Question] — **Deferred (non-blocking):** [Why this doesn't block implementation]
````
