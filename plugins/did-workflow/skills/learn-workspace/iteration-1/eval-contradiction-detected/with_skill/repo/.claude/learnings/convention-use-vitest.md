---
name: use-vitest
description: We migrated from Jest to Vitest last quarter; Jest only remains for one legacy package
type: convention
captured: 2026-02-10
source: /learn — initial capture during Q1 migration
---

Use Vitest for new and existing tests. Do not add new Jest tests.

**Why:** We migrated the primary test suite from Jest to Vitest in Q1 2026 for faster startup and native ESM support. The `packages/legacy-billing/` package still uses Jest because its CommonJS dependencies don't yet work cleanly under Vitest — that exception is tracked separately.

**How to apply:** New test files should import from `vitest` (`import { test, expect } from "vitest"`). When editing existing tests, keep them on whichever runner they're already using; don't mix runners in a single file. The only place a new Jest test is acceptable is inside `packages/legacy-billing/`, and even there the preference is to port it when feasible.
