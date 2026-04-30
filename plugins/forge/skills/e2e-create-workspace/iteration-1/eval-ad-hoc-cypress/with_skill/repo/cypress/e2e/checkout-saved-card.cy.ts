describe("checkout with a saved card", () => {
  it("user can add a product to their cart and check out with a saved card", () => {
    cy.visit("/");

    // Open a product from the listing and add it to the cart.
    cy.findAllByTestId("product-card").first().click();
    cy.url().should("match", /\/products\/sku-/);
    cy.findByRole("button", { name: /add to cart/i }).click();

    // The cart should reflect the added item.
    cy.findByRole("link", { name: /cart/i }).click();
    cy.url().should("include", "/cart");
    cy.findAllByTestId("cart-line-item").should("have.length.at.least", 1);

    // Proceed to checkout.
    cy.findByRole("button", { name: /checkout/i }).click();
    cy.url().should("include", "/checkout");

    // Pick an existing saved card rather than entering a new one.
    cy.findByRole("radio", { name: /saved card/i }).check({ force: true });

    // Place the order.
    cy.findByRole("button", { name: /place order/i }).click();

    // Outcome the user actually sees: a confirmation page with an order number.
    cy.url().should("match", /\/orders\/[A-Za-z0-9-]+/);
    cy.findByRole("heading", { name: /order confirmed/i }).should("be.visible");
    cy.findByText(/order #/i).should("be.visible");
  });
});
