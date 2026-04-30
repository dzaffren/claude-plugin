# Epic PRD Template

Use this template for the **parent spec** when a feature contains multiple stories. Each story gets its own `spec-{slug}.md` file using `template-feature.md` (user-facing) or `template-technical.md` (technical). This file contains shared context only — no acceptance criteria or detailed scenarios.

```markdown
# [Epic Name] — Overview

## Summary

[2-3 sentences: what this epic delivers, who it's for, and the primary value]

## Background & Context

**Current state:**

- [What exists today]
- [How users currently handle these needs]

**Problem:**

- [What's missing, broken, or inadequate]
- [Business impact of the current state]

## Goals

- [Primary goal 1]
- [Primary goal 2]

## Non-Goals (Optional — delete if not needed)

- [What this epic explicitly does NOT include]
- [Future work to explicitly defer]

## Story Index

| Ticket       | Story                 | Spec                         | Type        | Status      | Dependencies |
| ------------ | --------------------- | ---------------------------- | ----------- | ----------- | ------------ |
| [TICKET-123] | [Story name]          | [spec-slug.md](spec-slug.md) | User-facing | Not Started | —            |
| [TICKET-124] | [Story name]          | [spec-slug.md](spec-slug.md) | User-facing | Not Started | TICKET-123   |
| [TICKET-125] | [Technical task name] | [spec-slug.md](spec-slug.md) | Technical   | Not Started | —            |

## Shared Business Rules

- [Rule 1 — business logic that applies across multiple stories]
- [Rule 2 — constraint or policy shared by all stories]

## User Journey Map

> Describe the end-to-end user experience across all stories in this epic.
> This is a narrative — show how the stories connect from the user's perspective.

1. **[Starting point]** — [User's initial state and need] _(Story: [name])_
2. **[Next step]** — [What the user does and sees] _(Story: [name])_
3. **[Next step]** — [What the user does and sees] _(Story: [name])_
4. **[Completion]** — [How the user knows the full workflow is done]

## Success Metrics

- [Metric 1 — measurable business outcome for the entire epic]
- [Metric 2 — measurable user outcome]

## Dependencies

- [Dependency 1 — other features, teams, or business processes this epic depends on]
- [Dependency 2]

## Rollout Strategy (Optional — delete if not needed)

- [Story delivery order and rationale]
- [Phased rollout plan]
- [Communication plan for users]

## Open Questions

> Resolve all questions before implementation. Non-blocking questions may be deferred with rationale.

- [x] ~~[Question 1]~~ — **Resolved:** [Decision and rationale]
- [ ] [Question 2] — **Status:** [Awaiting input from...] ← BLOCKS IMPLEMENTATION
- [ ] [Question 3] — **Deferred (non-blocking):** [Why this doesn't block implementation]
```
