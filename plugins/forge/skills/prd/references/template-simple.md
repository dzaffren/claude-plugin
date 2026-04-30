# Simple Enhancement PRD Template

Use this template for **small enhancements and features** (< 1 day). Includes a user story.

````markdown
# [Feature Name]

**Ticket:** [TICKET-123 or TBD]
**Type:** Enhancement / Small Feature

[2-3 sentences: what this change does, what problem it solves, who benefits]

## User Story

As a [user type], I want to [action/capability] so that [benefit/value].

## Problem

**Current state:** [What exists today and why it's insufficient]

**Desired state:** [What should be true after this change]

## Target User

[Who is the primary user and what is their context when they encounter this]

## Scope

- **In scope:** [explicit list]
- **Out of scope:** [explicit list]

## Requirements

- [ ] [Requirement 1 — specific, testable]
- [ ] [Requirement 2 — specific, testable]
- [ ] [Requirement 3 — specific, testable]

## Acceptance Criteria

> Write scenarios from the **user's perspective** — describe what they see and do.
> Cover all happy paths, error cases, and edge cases. Be thorough.
> See `bdd-format.md` for full Gherkin rules.

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

## Success Metrics

- [Metric 1 — measurable business outcome, e.g., "reduce support tickets about X by 50%"]
- [Metric 2 — measurable user outcome]

## Open Questions

> Resolve all questions before implementation. Non-blocking questions may be deferred with rationale.

- [x] ~~[Question 1]~~ — **Resolved:** [Decision]
- [ ] [Question 2] — **Deferred (non-blocking):** [Why this doesn't block implementation]
````
