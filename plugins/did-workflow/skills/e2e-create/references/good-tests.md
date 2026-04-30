# Good and Bad E2E Tests

E2E tests prove the system works end-to-end for a real user. They are
expensive — slow to run, flake-prone, painful to debug — so every one has to
earn its keep. These patterns separate tests that catch real regressions from
tests that pass forever while the product quietly breaks.

## User journeys, not UI details

**Good: named after a user outcome.**

```typescript
test("user can recover a forgotten password", async ({ page }) => {
  await page.goto("/login");
  await page.getByRole("link", { name: "Forgot password?" }).click();
  await page.getByLabel("Email").fill("alice@example.com");
  await page.getByRole("button", { name: "Send reset link" }).click();

  const resetUrl = await getResetLinkFromTestInbox("alice@example.com");
  await page.goto(resetUrl);
  await page.getByLabel("New password").fill("new-secret-123");
  await page.getByRole("button", { name: "Reset password" }).click();

  await expect(page).toHaveURL("/login");
  await page.getByLabel("Email").fill("alice@example.com");
  await page.getByLabel("Password").fill("new-secret-123");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(
    page.getByRole("heading", { name: "Welcome back" }),
  ).toBeVisible();
});
```

The test name describes a capability the user has. The body exercises the real
flow — request reset, read the email, set a new password, sign in with it. If
any link in that chain breaks, this test catches it.

**Bad: named after a UI detail.**

```typescript
// BAD — tests a page element, not a user capability
test("clicking forgot password shows the reset form", async ({ page }) => {
  await page.goto("/login");
  await page.getByRole("link", { name: "Forgot password?" }).click();
  await expect(
    page.getByRole("heading", { name: "Reset password" }),
  ).toBeVisible();
});
```

This test passes when the reset feature is completely broken — as long as the
form renders. It's slow and fragile for the tiny amount of signal it provides.
Component tests cover this far better.

## Test pyramid discipline

E2E tests cover **the flow**, not every branch of every validation. If
`prd-refine` mapped a Key Scenario to E2E, it's because users care about that
outcome end-to-end. Edge cases (invalid inputs, specific error codes, rate
limiting) belong in integration or unit tests where they run fast and
deterministic.

One journey usually produces 1–3 E2E tests:

- The happy path
- One or two critical variants that share setup (e.g. expired reset token,
  password that fails strength rules)

Resist the urge to exhaustively enumerate validation errors — that's unit-test
territory.

## Observable outcomes, not internal state

**Good: assert on what the user sees.**

```typescript
await expect(page.getByText("Order #12345 confirmed")).toBeVisible();
await expect(page).toHaveURL(/\/orders\/12345/);
```

**Good: assert on what persisted, via the public API.**

```typescript
const order = await api.get(`/orders/${orderId}`);
expect(order.status).toBe("confirmed");
```

**Bad: reach past the interface to "verify."**

```typescript
// BAD — bypasses the system's own API to poke at the DB
const row = await db.query("SELECT status FROM orders WHERE id = ?", [orderId]);
expect(row.status).toBe("confirmed");
```

The DB query passes when the API is broken — the read path could be returning
stale data, applying bad permissions, or crashing, and the test wouldn't
notice. Always verify through the interface the user (or calling system)
actually uses.

**Bad: assert on mock call counts.**

```typescript
// BAD — this is a unit test wearing an E2E costume
expect(sendEmailSpy).toHaveBeenCalledWith("alice@example.com");
```

In E2E, the email system is real. Assert on the outcome: the email arrives
(check the test inbox), or the reset link works. Call counts are an
implementation detail; tomorrow someone might batch emails or switch providers,
and this test will fail for no user-visible reason.

## Stable selectors

Selectors are how your test finds elements. Bad selectors break every time
someone changes the CSS or copy.

**Preferred order:**

1. **Role-based** — `getByRole("button", { name: "Sign in" })`. Matches how
   accessibility tools and real users find elements. Survives CSS refactors.
2. **Test IDs** — `getByTestId("submit-order")`. Explicit contract: "this
   element is part of the test surface." Survives copy changes.
3. **Text** — `getByText("Welcome back")`. Fine for stable copy (page
   headings); risky for anything marketing might tweak.
4. **CSS / XPath** — last resort. `page.locator(".btn-primary > span:nth-child(2)")`
   is a time bomb.

Match whatever convention the project already uses. Don't mix strategies in
the same test — if the repo uses `data-testid` everywhere, follow suit.

## Test isolation

Every E2E test must be runnable on its own, in any order, without depending
on other tests having run first.

**Good: each test seeds its own state.**

```typescript
test("user can complete checkout", async ({ page }) => {
  const user = await api.createTestUser();
  const cart = await api.seedCart(user.id, [{ productId: "sku-1", qty: 2 }]);
  await loginAs(page, user);
  // ... run the test
});
```

**Bad: tests that assume a shared fixture.**

```typescript
// BAD — breaks if tests run in a different order, or one fails partway
test("step 1: user adds item", ...);
test("step 2: user checks out", ...); // depends on step 1
```

Tests like this fail mysteriously in CI, pass locally, and take hours to
debug. Keep each test self-sufficient.

**Namespace your data.** If the test creates a user, use a unique email
(`test-${Date.now()}@example.com` or a UUID). If it seeds a database row,
clean it up after. Shared fixtures are fine — shared _mutable_ state between
tests is not.

## Determinism

Flake is the fastest way to make a test suite worthless — once people start
hitting "retry," they stop trusting the signal, and real failures slip
through.

**Avoid hard sleeps.**

```typescript
// BAD — will either be too fast (flake) or too slow (wastes time)
await page.click("button");
await page.waitForTimeout(2000);
await expect(page.getByText("Saved")).toBeVisible();
```

**Use the framework's auto-waiting.**

```typescript
// GOOD — retries until the assertion passes or times out
await page.click("button");
await expect(page.getByText("Saved")).toBeVisible();
```

**Avoid real third-party calls.** If your test hits the live Stripe API or a
real SendGrid account, you're one network blip away from a red build. Use the
vendor's test/sandbox mode, a local mock server (MSW, WireMock), or a
fixture. If there's no way to isolate the third party, BLOCK and raise it —
don't paper over it with retries.

**Avoid timing-sensitive assertions.** "The toast appears for 3 seconds" is
a test that will flake. Assert that the toast appeared; trust component tests
to cover the timing.

## When to BLOCK instead of writing the test

Some conditions mean the test can't be written reliably. Report rather than
force it:

- The flow's entry point is unclear (no stable URL, no seedable starting state).
- Required fixtures or seed data don't exist and building them is outside this
  skill's scope.
- Target elements have no stable selectors and the project has no selector
  convention you can extend.
- The test would need to mock an internal service, which violates the point
  of E2E.
- The framework needs configuration that doesn't exist yet (global setup,
  authentication storage state, a running dev server wiring).

A blocked test is better than a flaky test. Flaky tests train everyone to
ignore failures.
