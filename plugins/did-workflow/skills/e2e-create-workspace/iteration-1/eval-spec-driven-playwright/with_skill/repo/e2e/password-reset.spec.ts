import { test, expect, request } from "@playwright/test";

/**
 * Fetches the most recent password-reset URL delivered to `email` from the
 * app's test-only inbox endpoint. This relies on the backend exposing
 * `GET /api/test/inbox?email=...` in non-production environments — the
 * email pipeline (sub-task 3) writes sent messages there for E2E to read.
 *
 * NOTE: This is the first E2E test in the repo to need inbox access. If the
 * test-inbox endpoint does not yet exist, this helper and the happy-path
 * test will need that endpoint to be added (or swapped for whatever test
 * mailbox the project adopts).
 */
async function getResetLinkFromTestInbox(email: string): Promise<string> {
  const api = await request.newContext();
  const res = await api.get(
    `/api/test/inbox?email=${encodeURIComponent(email)}`,
  );
  expect(res.ok()).toBeTruthy();
  const messages = (await res.json()) as Array<{ body: string }>;
  const latest = messages[messages.length - 1];
  const match = latest?.body.match(/https?:\/\/\S*\/reset-password\?token=\S+/);
  if (!match) {
    throw new Error(`No reset link found in inbox for ${email}`);
  }
  return match[0];
}

test("user can recover a forgotten password", async ({ page }) => {
  const email = "alice@example.com";
  const newPassword = "new-secret-123";

  await page.goto("/login");
  await page.getByRole("link", { name: "Forgot password?" }).click();
  await page.getByLabel("Email").fill(email);
  await page.getByRole("button", { name: "Send reset link" }).click();

  await expect(
    page.getByText("If an account exists, a reset link has been sent"),
  ).toBeVisible();

  const resetUrl = await getResetLinkFromTestInbox(email);
  await page.goto(resetUrl);
  await page.getByLabel("New password").fill(newPassword);
  await page.getByRole("button", { name: "Reset password" }).click();

  await expect(page).toHaveURL("/login");

  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(newPassword);
  await page.getByRole("button", { name: "Sign in" }).click();

  await expect(
    page.getByRole("heading", { name: "Welcome back" }),
  ).toBeVisible();
  await expect(page).toHaveURL("/dashboard");
});

test("user sees an expired-link message when opening a stale reset link", async ({
  page,
}) => {
  // The backend exposes a test-only seeding endpoint that mints a reset token
  // with a backdated issued-at, so the link is already expired when visited.
  const api = await request.newContext();
  const seed = await api.post("/api/test/reset-tokens", {
    data: { email: "bob@example.com", ageSeconds: 60 * 60 + 60 },
  });
  expect(seed.ok()).toBeTruthy();
  const { url: expiredUrl } = (await seed.json()) as { url: string };

  await page.goto(expiredUrl);

  await expect(page.getByText("This reset link has expired")).toBeVisible();
  await expect(
    page.getByRole("link", { name: "Request a new one" }),
  ).toBeVisible();
});

test("forgot-password form shows the same confirmation for an unregistered email", async ({
  page,
}) => {
  await page.goto("/login");
  await page.getByRole("link", { name: "Forgot password?" }).click();
  await page.getByLabel("Email").fill("not-a-user@example.com");
  await page.getByRole("button", { name: "Send reset link" }).click();

  await expect(
    page.getByText("If an account exists, a reset link has been sent"),
  ).toBeVisible();

  // No indication that the account does not exist — no "email not found" text,
  // no different heading, no redirect to a different page.
  await expect(
    page.getByText(/no account|not found|does not exist/i),
  ).toHaveCount(0);
});
