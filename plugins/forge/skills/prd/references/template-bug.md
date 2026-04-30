# Bug Report PRD Template

Use this template for **bug reports**. No user story — focus on current vs. expected behavior.

````markdown
# [Bug Name]

**Ticket:** [TICKET-123 or TBD]
**Type:** Bug Report
**Severity:** [Critical / High / Medium / Low]

[2-3 sentences: what is broken, who is affected, and when it occurs]

## Current Behavior

[What happens now — describe from the user's perspective]

**Reproduction steps:**

1. [Step 1]
2. [Step 2]
3. [Step 3]

- **Expected:** [what the user should see]
- **Actual:** [what the user actually sees]

## Expected Behavior

[What should happen instead — describe the correct experience from the user's perspective]

## Impact

- **Who is affected:** [which users/personas are impacted]
- **Severity:** [how badly — data loss, blocked workflow, cosmetic, etc.]
- **Frequency:** [how often it occurs — always, intermittently, under specific conditions]
- **Workaround:** [is there a workaround, or are users completely blocked?]

## Scope

- **In scope:** [what this fix should address]
- **Out of scope:** [what this fix should NOT address — related issues to defer]

## Acceptance Criteria

> Write scenarios from the **user's perspective** — describe what they see and do.
> Cover the fix, regression prevention, and any edge cases.
> See `bdd-format.md` for full Gherkin rules.

### Scenario: [Fixed behavior — happy path]

```gherkin
Given [precondition in user-visible terms]
When [user action that previously triggered the bug]
Then [correct behavior the user should now see]
```

### Scenario: [Edge case related to the bug]

```gherkin
Given [related precondition]
When [user action]
Then [expected correct behavior]
```

## Open Questions

> Resolve all questions before implementation. Non-blocking questions may be deferred with rationale.

- [x] ~~[Question 1]~~ — **Resolved:** [Decision]
- [ ] [Question 2] — **Deferred (non-blocking):** [Why this doesn't block implementation]
````
