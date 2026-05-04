# Learning Types — Worked Examples

Each learning type has a specific purpose. Picking the right type matters
because consumers of the index read by type first. A convention and a
blocker are consumed at different moments by different skills.

## Convention — "how code should look"

Team decisions about style, structure, or approach. These are rules with no
single incident behind them — someone decided, and everyone agreed.

```markdown
---
name: no-inline-styles
description: Components use CSS modules, not inline styles
type: convention
captured: 2026-04-28
source: /ship — PR #234 review comment
---

Do not use inline `style={{ ... }}` props on React components.

**Why:** Design tokens live in `src/styles/tokens.css` and inline styles
bypass them, producing inconsistent spacing and colors. Reviewer caught
this on PR #234.

**How to apply:** When writing any React component, create a sibling
`<Name>.module.css` and import class names. Check `src/styles/utilities.css`
for existing classes before writing new CSS.
```

Good convention captures are **scoped** (React components, backend
handlers, new endpoints — not "everywhere") and have a **concrete
why** a future reader can evaluate.

## Blocker — "what was tried and what failed"

A dead-end encountered during work, with enough detail that the next run
doesn't retread it. Unlike conventions, blockers have a specific incident.

```markdown
---
name: vitest-workspace-parallel-hang
description: Vitest workspace config hangs in CI without VITEST_POOL=1
type: blocker
captured: 2026-04-28
source: /build — APP-789 feature-builder run
---

Vitest workspace mode hangs indefinitely in CI when the default parallel
pool is used. Tests pass locally but CI jobs time out at 10 minutes.

**Why:** Our CI runners have 2 CPUs but Vitest defaults to spawning
`os.cpus()` worker threads, which fight for resources and deadlock on the
shared SQLite fixture. Local machines have 8+ cores so the issue doesn't
reproduce.

**How to apply:** When editing `vitest.config.ts` or adding new packages
to the workspace, confirm `VITEST_POOL=1` is set in `.github/workflows/*.yml`.
Any CI failure with a 10-minute timeout on the test stage is probably
this — check pool config first.

**What was tried:** Increased CI job timeout (didn't help — deadlock is
permanent). Switched to `pool: 'forks'` (slower, still hung intermittently).
Moved to threads with `maxThreads: 1` — works, but `VITEST_POOL=1` is the
documented equivalent.
```

Good blocker captures include **what was tried** so the next run can skip
the failed branches.

## Pattern — "reusable project-specific approach"

A specific way this project solves a recurring problem. Unlike a
convention (which is a rule about how things should look), a pattern is a
concrete building block.

```markdown
---
name: auth-test-seeding
description: Auth tests use seedUserWithRole fixture for deterministic users
type: pattern
captured: 2026-04-28
source: /learn — user capture during session
---

Every test that exercises an authenticated endpoint should create its user
via the `seedUserWithRole(role, overrides?)` fixture in
`test/fixtures/users.ts`.

**Why:** Direct DB inserts bypass the password hashing, 2FA defaults, and
audit-log side effects that real user creation goes through. Tests that
used raw inserts passed locally but failed when those defaults changed in
prod.

**How to apply:** In any test under `src/**/__tests__/` that logs in or
impersonates a user, import from `test/fixtures/users` rather than
writing to the `users` table directly. The fixture namespaces emails with
a UUID so parallel test runs don't collide.
```

Good pattern captures name the **specific fixture, helper, or module** to
use — not a vague "do it the right way."

## Win — "this approach worked, repeat it"

The positive counterpart to a blocker. Something was tried, it worked well,
and the team should lean on it the next time a similar situation comes up.

```markdown
---
name: msw-for-auth-tests
description: Using msw for network mocks kept auth tests under 200 lines
type: win
captured: 2026-05-01
source: /build — auth feature feature-builder run
---

Auth tests that mock network calls with `msw` (Mock Service Worker) stay
small, readable, and stable across refactors.

**Why:** The previous approach wrapped `fetch` with hand-rolled jest mocks,
which broke every time a caller added a header or changed an endpoint. `msw`
intercepts at the network layer so the test code doesn't know or care about
fetch wrappers.

**How to apply:** For any test under `src/auth/**/__tests__/` that needs to
mock an outbound API call, reach for `msw` handlers in `test/msw/handlers/`
before writing a new jest mock. The handler file organization mirrors
`src/api/`.

**What worked:** Installing `msw@2` + creating a shared `test/msw/server.ts`
that starts in `beforeAll` and resets between tests. One-time setup,
per-test handlers as needed. Kept each auth test under 200 lines and
survived the fetch-wrapper refactor in May without any test edits.
```

Good win captures are **specific** (named library/pattern, named path) and
include **What worked** so the replay is straightforward — "we did X, and
the concrete moves were A, B, C."

## Skill-quality — "a workflow skill got it wrong"

When Claude ran a forge skill (`/prd`, `/build`, `/ship`, etc.) and
produced output the user had to correct, the correction itself is a
learning. Unlike the other types, this one is about the **skill's
behavior** in this repo, not about the repo's code.

```markdown
---
name: prd-refine-missing-migrations
description: prd-refine omits migration sub-tasks for Rails repos
type: skill-quality
captured: 2026-04-28
source: /prd-refine — APP-102 spec review
skill: prd-refine
---

prd-refine consistently forgets to add a "database migration" sub-task when
the feature touches a model in this Rails repo, even when a migration is
clearly needed.

**Why:** prd-refine's generic Implementation Plan template biases toward
"endpoint + frontend + tests" and doesn't include Rails-specific stages.
Our CI requires the migration and the code in the same PR, so missing it
forces a rewrite.

**How to apply:** When running `/prd-refine` against this repo, verify the
Implementation Plan includes a sub-task for the migration (with
`db/migrate/*.rb` in the file paths) before approving. If it's missing,
add it explicitly — don't assume the code-only plan is sufficient.
```

Good skill-quality captures name the **specific skill** in the frontmatter
and describe the **recurring failure mode**, not a one-off mistake. One
miss isn't a learning; a pattern of misses is.

## Borderline cases

**"We always squash merge."** Convention — a team decision about code flow.

**"The staging deploy broke because of a missing env var last week."** Not
a learning by itself — that's an incident log. A learning would be "New
env vars must be added to `staging.env.example` as well as the CI secret."

**"This function is slow."** Not a learning — it's a code smell. Fix the
code. A learning would apply only if there's a specific constraint
explaining the slowness that a future run would otherwise miss.

**"I prefer tabs over spaces."** User preference, not team convention.
Belongs in personal auto-memory, not repo learnings.

**"The `Order` model has a soft-delete column that most queries need to
filter out."** Pattern — a reusable project-specific fact. High-value
because new code written against `Order` will likely miss this.
