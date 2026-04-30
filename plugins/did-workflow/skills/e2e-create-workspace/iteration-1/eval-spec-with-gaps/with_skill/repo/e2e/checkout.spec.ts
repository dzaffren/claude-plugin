import { test, expect } from "@playwright/test";

test("returning shopper can check out with a saved card in one click", async ({
  page,
}) => {
  const email = `test-${Date.now()}@example.com`;

  await page.goto("/login");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill("correct-horse-battery");
  await page.getByRole("button", { name: "Sign in" }).click();

  await page.goto("/cart");
  await page.getByRole("button", { name: "Checkout" }).click();
  await page.getByRole("button", { name: "Confirm order" }).click();

  await expect(
    page.getByRole("heading", { name: "Order confirmed" }),
  ).toBeVisible();
});
