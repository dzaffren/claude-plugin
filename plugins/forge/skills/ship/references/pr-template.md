# Pull Request Template

Use this template when creating a GitHub pull request. Fill in each section based on the branch's commits and changes. Remove sections that don't apply.

---

```markdown
## Summary

- [1-3 bullet points: what this PR does and why]

## Ticket

[TICKET-123](link) or N/A

## Changes

[Logical change groups — organize by module or concern, not by file. Reference key commits if helpful.]

## How to Test

1. [Step-by-step testing instructions]
2. [Include setup steps if needed]
3. [Describe expected outcomes]

## Checklist

- [ ] Code follows project conventions
- [ ] Tests added/updated for changed behavior
- [ ] No unrelated changes included
- [ ] Branch is up to date with target
```

---

## Guidelines

- **Summary**: Lead with the "why", not just the "what". A reviewer should understand the motivation from the summary alone.
- **Ticket**: Link the ticket if a ticket ID is known. Use `N/A` if there is no ticket.
- **Changes**: Group logically. "Added auth middleware + updated route handlers" is better than listing 12 files.
- **How to Test**: Write for someone unfamiliar with the change. Include commands to run, pages to visit, or API calls to make.
- **Checklist**: Check items that are done. Leave unchecked items as reminders for the author.
- **Do not** mention Claude, Claude Code, AI, or any AI tool in the PR title or body.
- **Draft PRs**: Create as draft when the user explicitly says "draft" or when work is incomplete.
