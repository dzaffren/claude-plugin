# Technical Task PRD Template

Use this template for **technical work with no end-user story** — refactoring, infrastructure, dependency upgrades, performance optimization, security hardening, migrations, tech debt, etc. No user story — frames work around problem and motivation.

````markdown
# [Task Name]

**Ticket:** [TICKET-123 or TBD]
**Type:** Technical — [Refactor / Infrastructure / Dependency Upgrade / Performance / Security / Migration / Tech Debt]

[2-3 sentences: what this work is, why it matters, what it unblocks or protects]

## Motivation

[Why this work needs to happen now. Frame in terms of risk, cost, or what it unblocks — not in terms of a user wanting something.]

**Current state:** [What exists today and why it's a problem]

**Desired state:** [What should be true after this work is done]

**Trigger:** [What prompted this work — incident, audit finding, blocked feature, tech debt threshold, upcoming deprecation, compliance requirement, etc.]

## Scope

- **In scope:** [explicit list]
- **Out of scope:** [explicit list]

## Goals

- [Goal 1 — measurable from a business or operational perspective, e.g., "reduce P99 latency below 200ms"]
- [Goal 2 — e.g., "eliminate manual deployment step"]
- [Goal 3]

## Non-Goals

- [What this work explicitly does NOT include]
- [Related improvements to explicitly defer]

## Success Criteria

- [Criterion 1 — observable, measurable outcome from a business/operational perspective]
- [Criterion 2 — how you know this work achieved its goal]

## Acceptance Criteria

> Write operational scenarios where applicable. Use Gherkin format from the perspective
> of the system's observable behavior — not implementation details.
> See `bdd-format.md` for full Gherkin rules.

### Scenario: [Operational scenario description]

```gherkin
Given [system precondition in observable terms]
When [trigger or action]
Then [observable system outcome]
  And [additional observable outcome]
```

### Scenario: [Failure/degradation scenario]

```gherkin
Given [failure precondition]
When [trigger or action]
Then [expected graceful behavior]
```

## Constraints

- **Backwards compatibility:** [Must maintain / can break with migration / N/A]
- **Downtime:** [Zero-downtime required / maintenance window acceptable / N/A]
- **Compliance:** [Regulatory or policy requirements, if applicable]
- **Rollback:** [Must be reversible / acceptable to be one-way / N/A]

## Dependencies

- [Dependency 1 — other teams, services, or business processes this depends on]
- [Dependency 2]

## Open Questions

> Resolve all questions before implementation. Non-blocking questions may be deferred with rationale.

- [x] ~~[Question 1]~~ — **Resolved:** [Decision and rationale]
- [ ] [Question 2] — **Deferred (non-blocking):** [Why this doesn't block implementation]
````
