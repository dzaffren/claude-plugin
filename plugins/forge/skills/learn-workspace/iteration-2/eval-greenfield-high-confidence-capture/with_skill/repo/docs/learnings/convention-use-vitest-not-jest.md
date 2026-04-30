---
name: use-vitest-not-jest
description: All tests use Vitest; Jest config remains only for one legacy package
type: convention
captured: 2026-04-28
source: /learn — user capture during session
---

Always use Vitest for tests in this repo. Do not add, extend, or rely on Jest.

**Why:** The team migrated the test suite from Jest to Vitest last quarter.
The remaining Jest configuration is retained solely to support one legacy
package and is not the default test runner. New tests written against Jest
would diverge from the rest of the suite and have to be migrated again.

**How to apply:** When adding or updating tests anywhere in the repo, use
Vitest APIs and run them with `pnpm test` (`vitest run`). Do not introduce
new files that import from `jest` or rely on Jest-specific globals. If you
find yourself working inside the one legacy package that still uses Jest,
confirm with the user before extending its Jest surface — for everything
else, reach for Vitest.
