# Feature PRD Template

Use this template for **single user-facing features**. Includes a user story. Maps 1:1 to a ticket.

````markdown
# [Feature Name]

**Ticket:** [TICKET-123 or TBD]

[2-3 sentences: what this feature does, what problem it solves, who benefits]

## User Story

As a [user type], I want to [action/capability] so that [benefit/value].

## Background & Context

**Current state:**

- [What exists today]
- [How users currently handle this need]

**Problem:**

- [What's missing, broken, or inadequate]
- [Business impact of the current state]

## Target User & Persona

- **Who:** [User type and role]
- **Context:** [When and where they encounter this need]
- **Current workaround:** [How they handle it today, if at all]

## Goals

- [Goal 1 — what this feature should achieve]
- [Goal 2]

## Non-Goals (Optional — delete if not needed)

- [What this feature explicitly does NOT include]
- [Future work to explicitly defer]

## User Workflow

> Describe the step-by-step experience from the user's perspective. No technical details —
> focus on what the user sees, does, and feels at each step.

1. **[Starting point]** — [What the user sees and their intent]
2. **[Action]** — [What the user does]
3. **[Response]** — [What the user sees as a result]
4. **[Completion]** — [How the user knows they're done]

## Acceptance Criteria

> Write scenarios from the **user's perspective** — describe what they see and do.
> Cover all happy paths, error cases, edge cases, and business rules. Be thorough.
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

## Business Rules & Constraints

- [Rule 1 — specific constraint or business logic with concrete values]
- [Rule 2 — what happens when the rule is violated, from the user's perspective]

## Success Metrics

- [Metric 1 — measurable business outcome]
- [Metric 2 — measurable user outcome]

## Dependencies

- [Dependency 1 — other features or business processes this depends on (NOT code dependencies)]
- [Dependency 2]

## Rollout Considerations (Optional — delete if not needed)

- [Phased rollout plan, if applicable]
- [A/B testing considerations]
- [Communication plan for users]

## Open Questions

> Resolve all questions before implementation. Non-blocking questions may be deferred with rationale.

- [x] ~~[Question 1]~~ — **Resolved:** [Decision and rationale]
- [ ] [Question 2] — **Deferred (non-blocking):** [Why this doesn't block implementation]
````
