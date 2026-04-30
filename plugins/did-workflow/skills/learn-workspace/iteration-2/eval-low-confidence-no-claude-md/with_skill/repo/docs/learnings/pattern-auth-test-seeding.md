---
name: auth-test-seeding
description: Auth tests tend to use the `seedUserWithRole` fixture (observed tendency, not a hard rule)
type: pattern
captured: 2026-04-28
source: /learn — user capture during session
---

Auth tests in this repo tend to use the `seedUserWithRole` fixture to set
up users. This is an observed tendency rather than a hard rule — the user
noted it as "something they've noticed," not a team mandate.

**Why:** The user flagged this as a pattern they've noticed across auth
tests. A concrete rationale wasn't given; typical motivations for a shared
seed fixture are deterministic user creation, consistent role assignment,
and avoiding duplication across test files. Confirm with the team before
treating this as canonical.

**How to apply:** When writing or reviewing a new auth-related test, check
whether `seedUserWithRole` already exists in the repo's test fixtures and
prefer it over ad-hoc user creation. Because confidence is low, don't
rewrite existing tests that take a different approach — just lean toward
the fixture for new tests, and revisit this learning if a team member
confirms or contradicts it.
