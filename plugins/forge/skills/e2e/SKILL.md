---
name: e2e
description: >
  Detects the project's E2E framework, runs the full E2E suite, and reports
  pass/fail. Use this skill after writing E2E tests or when you need to validate
  end-to-end flows. Stack-agnostic (Playwright, Cypress, others).
---

# E2E

Run the project's E2E test suite and report the outcome.

## Step 1 — Detect E2E framework

Check in this order:

1. `playwright.config.*` → Playwright (`npx playwright test`)
2. `cypress.config.*` or `cypress/` directory → Cypress (`npx cypress run`)
3. `package.json` scripts with keys containing `e2e` → run that script (`npm run <e2e-script>`)
4. A top-level `e2e/` or `tests/e2e/` directory with test files → infer runner from file contents

If no E2E framework is found, respond with:

```
NO_E2E: No E2E framework detected. Skipping.
```

and stop.

## Step 2 — Run the suite

Run the detected command. Capture stdout and stderr.

- Do not modify any test files before running.
- Do not skip or filter tests unless the project's config already does so.
- Allow up to 2 minutes for the suite to complete.

## Step 3 — Report result

**PASS** — all tests passed. Respond with:

```
PASS: E2E suite passed. {N} tests ran.
```

**FAIL** — one or more tests failed. Respond with:

```
FAIL: {N} test(s) failed.

Failed tests:
- {test name}: {failure reason / assertion message}
...

Raw output (last 50 lines):
{truncated output}
```

**ERROR** — the suite couldn't run (missing dependencies, config error, port conflict, etc). Respond with:

```
ERROR: E2E suite could not run.
Reason: {specific error message}
Suggested fix: {one-line suggestion}
```

## Constraints

- Do NOT attempt to fix failing tests — report and stop.
- Do NOT install missing dependencies — report what's missing.
- Do NOT start servers or services required by the tests — if they aren't running, report `ERROR`.
- Truncate output to the last 50 lines to avoid flooding the caller's context.
