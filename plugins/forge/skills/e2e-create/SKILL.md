---
name: e2e-create
description: >
  Authors end-to-end tests in the project's existing E2E framework (Playwright,
  Cypress, or other). Use this skill whenever the user wants to add, write, or
  cover a user-facing flow with an E2E test — even if they don't say "E2E"
  explicitly (phrases like "write a browser test for login", "cover the
  checkout flow end-to-end", or "add a Playwright test for password reset" all
  apply). Also invoked by the `feature-builder` agent after implementation when
  the spec's Verification section assigns E2E rows to a sub-task.
  This skill writes tests only — it does not run them. Invoke the `e2e` skill
  to execute the suite afterward.
---

# E2E Create

Author end-to-end tests that exercise a user journey through the real running
system. One invocation covers one user journey — typically 1–3 tightly related
tests that share setup (a happy path plus critical variants). Resist bundling
unrelated journeys into the same call; each invocation should leave the suite
with a coherent new slice of coverage.

## Reference Guides

| File                                                 | What it covers                                                      |
| ---------------------------------------------------- | ------------------------------------------------------------------- |
| [references/good-tests.md](references/good-tests.md) | Good vs bad E2E examples, selector strategy, isolation, determinism |

Read [references/good-tests.md](references/good-tests.md) before writing the first test in a new
project, or any time the exemplar check in Step 3 is inconclusive. The patterns
there are the difference between tests that catch real regressions and tests
that pass forever while the product quietly breaks.

## Philosophy

E2E tests exist to prove that a user can accomplish something through the real
running system. They are the top of the test pyramid — the slowest, most
expensive, most flake-prone tests we have. That expense is only worth paying
when a unit or integration test genuinely cannot give you the same signal.

So every E2E test should describe a **user journey** (what the user
accomplishes), not a page or a component. Titles like
`"user can recover a forgotten password"` are good;
`"clicking the reset button shows the modal"` is testing a UI detail that
should live in a component test.

The assertions should be on outcomes the user (or a downstream system)
actually observes: text on the screen, the final URL, a received email, a
record retrievable through the public API. Not internal state, not mock call
counts, not "was this function called."

## Step 1 — Find the source of truth for scenarios

Scenarios come from one of two places, in this priority order:

1. **The spec.** If a spec file exists (typically `docs/specs/<ticket>-<name>/spec*.md`),
   open its `Verification` section and look for an `E2E Tests` table. Each row maps
   a Key Scenario to a test file path and an assigned sub-task. If you are writing
   for a specific sub-task, take the rows assigned to it. The Key Scenarios
   elsewhere in the spec (Given/When/Then) describe what the test should exercise.

2. **The caller's description.** If there is no spec, or the spec has no E2E table,
   use the flow the caller described directly.

Do NOT brainstorm additional scenarios. Inventing coverage the spec did not ask
for is `prd-refine`'s job, not this skill's. If the spec's E2E table looks
incomplete or missing scenarios you believe matter, report it in your final
message rather than silently adding tests — the caller can decide whether to
loop back to `prd-refine`.

## Step 2 — Detect the E2E framework

Check in this order:

1. `playwright.config.*` → Playwright. `testDir` in the config tells you where
   tests live (default `tests/` or `e2e/`). File pattern is typically `*.spec.ts`.
2. `cypress.config.*` or a `cypress/` directory → Cypress. Tests live under
   `cypress/e2e/`. File pattern is `*.cy.ts` or `*.cy.js`.
3. `package.json` scripts with an `e2e`-keyed script (e.g. `"e2e"`, `"test:e2e"`)
   → open the script, infer the runner from its command, then follow that
   runner's conventions.
4. A top-level `e2e/` or `tests/e2e/` directory with existing test files → read
   a test to infer the runner, imports, and file naming.

If nothing is detected, respond:

```
NO_E2E: No E2E framework detected. Skipping — add a framework before authoring.
```

and stop. Do NOT install, scaffold, or suggest a specific framework — that's a
project-level decision, not a per-test decision.

## Step 3 — Read an exemplar

Before writing anything, read ONE existing E2E test in the repo end-to-end.
This is where the project's actual conventions live — the written docs lie,
the exemplar does not. Match:

- **Imports and helpers** — what fixtures, page objects, or custom commands does
  the project use? Reuse them.
- **Selector strategy** — is the project using `data-testid`, role-based
  (`getByRole`), or text-based selectors? Pick the same one.
- **Setup and teardown** — how do tests handle auth? (seeded user? API login?
  storage state?) How is data reset between tests?
- **Naming** — what does `describe` / `test` naming look like? Match the voice.

If there is no exemplar (this is the first E2E test in the repo), fall back to
the framework's idiomatic style as documented in [references/good-tests.md](references/good-tests.md),
and flag this in your final report so the caller knows you just established a
convention others will follow.

## Step 4 — Write the tests

For each scenario in scope (one user journey, 1–3 related tests):

- **Name the test after the user outcome.** `"user can recover a forgotten
password"`, not `"POST /reset returns 200"`. A stranger reading the test name
  should understand what capability the system provides.
- **Start from an observable entry point.** A URL, a login via API, a seeded
  fixture. Not a direct DB insert that bypasses the interface you're testing.
- **Drive the system through its real surface.** Click real buttons, fill real
  inputs, wait for real navigations. If you have to reach into app internals to
  make the test work, the test is lying.
- **Assert on user-visible outcomes.** Text on screen, the final URL, a
  received email, a record retrievable through the public API. Not "was
  `sendEmail` called once" — that's an implementation detail wearing an E2E
  costume.
- **Use the project's selector convention consistently.** Prefer `getByRole`
  and `getByTestId` over brittle CSS or copy-paste text that marketing will
  change next sprint.
- **Rely on the framework's auto-waiting.** Playwright's `expect(locator)` and
  Cypress's `cy.contains` retry automatically. Hard sleeps (`waitFor(2000)`)
  are the #1 source of flake — avoid them.
- **Each test must be independently runnable.** Seed its own state, clean up
  or namespace its own data, don't depend on a prior test having run. If two
  tests need the same setup, share a fixture — don't share state.

See [references/good-tests.md](references/good-tests.md) for worked examples of each of these points.

## Step 5 — Place the file

- If the spec specified a path, use it exactly.
- Otherwise, place alongside the exemplar using the framework's convention:
  Playwright → `testDir` from config; Cypress → `cypress/e2e/`; other → the
  existing `e2e/` or `tests/e2e/` directory.
- Do NOT create a new top-level test directory if one already exists. The goal
  is for these tests to look like they've always been there.

## Step 6 — Report

Respond with:

```
WROTE: {path}
Scenarios covered:
- {one-line description per test}
Framework: {playwright|cypress|other}
Next: invoke the `e2e` skill to run the suite.
```

If a spec exists but its E2E table looked incomplete, add:

```
NOTE: The spec's E2E table does not cover {scenario}. Consider revisiting
prd-refine if this flow should be covered.
```

If you could not write the test, respond:

```
BLOCKED: {reason}
Needs: {what the caller should clarify, add, or build first}
```

Common blockers: the flow's entry point isn't clear, required fixtures or
seed data don't exist, selectors for the target elements aren't stable, the
framework needs configuration that isn't this skill's job.

## Constraints

- **Do NOT install frameworks, plugins, or dependencies.** If the project
  doesn't have Playwright, this skill doesn't add it.
- **Do NOT scaffold new E2E infrastructure** (global setup, custom fixtures,
  new page objects) unless a test genuinely cannot be written without it. If
  you do add infrastructure, flag it in your report — the team needs to know
  a new pattern was introduced.
- **Do NOT mock internal services in E2E tests.** The whole point of an E2E
  test is to exercise the real system. If a real dependency is unavailable
  (e.g. a third-party API with no sandbox), BLOCK rather than substitute a
  mock — that's a conversation for the caller.
- **Do NOT run the suite.** The `e2e` skill does that. Separation of
  concerns: this skill authors, that skill executes. Mixing them makes both
  harder to reason about.
- **One user journey per invocation.** Multiple unrelated journeys belong in
  separate calls so each invocation has a coherent scope.
