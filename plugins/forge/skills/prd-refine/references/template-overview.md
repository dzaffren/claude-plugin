# Overview Spec Template

Use this template for the **parent spec** when a feature contains multiple user stories. Each story gets its own `spec-{slug}.md` file using `template-story.md`. This file contains shared context only — no scenarios, API design, or acceptance criteria.

````markdown
# [Feature Name] — Overview

## Summary

[2-3 sentences: what this feature group does, who it's for, and the primary value it delivers]

## Background & Context

**Current behavior:**
- [What exists today]

**Problem:**
- [What's missing or broken]

## Goals

- [Primary goal 1]
- [Primary goal 2]

## Non-Goals (Optional — delete if not needed)

- [What this feature explicitly does NOT include]
- [Future work to explicitly defer]

## Story Index

| Ticket | Story | Spec | Status | Dependencies |
|--------|-------|------|--------|--------------|
| [TICKET-123] | [Story name] | [spec-slug.md](spec-slug.md) | Not Started | — |
| [TICKET-124] | [Story name] | [spec-slug.md](spec-slug.md) | Not Started | TICKET-123 |

## Dependencies & Integration

- **Affected features:** [Which existing features/flows does this change interact with or affect?]
- **Shared state:** [Any shared data, caches, or state that other features rely on]
- **Breaking changes:** [Does this change any existing API contracts, data shapes, or behaviors?]
- **Migration path:** [If breaking, how do consumers transition?]

## Shared Data Model (Optional — delete if not needed)

[Shared schema/types that apply across multiple stories. Story-specific schema goes in the story spec.]

**Table: `[table_name]`**

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | uuid | PK | Unique identifier |
| field1 | string | Required, max 255 | [Purpose] |

## Shared Architecture Notes (Optional — delete if not needed)

[Cross-cutting concerns like shared services, auth patterns, or architectural decisions that affect all stories]

## Open Questions

> Resolve all questions before implementation. Non-blocking questions may be deferred with rationale.

- [x] ~~[Question 1]~~ — **Resolved:** [Decision and rationale]
- [ ] [Question 2] — **Status:** [Awaiting input from...] ← BLOCKS IMPLEMENTATION
- [ ] [Question 3] — **Deferred (non-blocking):** [Why this doesn't block implementation]
````
