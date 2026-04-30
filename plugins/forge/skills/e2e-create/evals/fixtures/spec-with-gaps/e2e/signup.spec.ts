import { test, expect } from "@playwright/test";

test("new user can create an account", async ({ page }) => {
  const email = `test-${Date.now()}@example.com`;
  await page.goto("/signup");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill("correct-horse-battery");
  await page.getByRole("button", { name: "Create account" }).click();

  await expect(
    page.getByRole("heading", { name: "Welcome to Acme" }),
  ).toBeVisible();
});
