describe("product browsing", () => {
  it("user can see products on the home page", () => {
    cy.visit("/");
    cy.findByRole("heading", { name: /featured products/i }).should("exist");
    cy.findAllByTestId("product-card").should("have.length.at.least", 1);
  });

  it("user can open a product detail page", () => {
    cy.visit("/");
    cy.findAllByTestId("product-card").first().click();
    cy.url().should("match", /\/products\/sku-/);
    cy.findByRole("button", { name: /add to cart/i }).should("be.visible");
  });
});
