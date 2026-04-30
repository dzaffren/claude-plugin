# APP-456 — Checkout with Saved Card

## User Story

As a returning shopper, I want to check out using a card I've saved on my account so that I can complete my purchase without re-entering payment details.

## Acceptance Criteria

- **Given** a logged-in user with a saved card and items in their cart, **when** they click "Checkout", **then** they can place the order in one step.
- **Given** a user with no saved card, **when** they click "Checkout", **then** they're taken to the payment form.
- **Given** a user whose saved card is expired, **when** they click "Checkout", **then** they see a warning and are prompted to update it before placing the order.
- **Given** a payment that fails (declined card), **when** the user places the order, **then** the order is not created and they see the decline reason.

## Scope

In scope: checkout with saved cards for standard accounts.
Out of scope: guest checkout, gift cards, split payments.

---

## Key Scenarios

**KS-1 — One-click checkout with saved card**

- Given: Alice is logged in, has a valid saved card, and has 2 items in her cart.
- When: She clicks "Checkout" and confirms.
- Then: Her order is placed and she sees an order confirmation.

**KS-2 — Expired card prompt**

- Given: Bob is logged in with a saved card that expired last month.
- When: He clicks "Checkout".
- Then: He sees "Your card has expired — please update it to continue" and a link to his payment settings.

**KS-3 — Declined card**

- Given: Carol is logged in with a valid-looking saved card that the gateway will decline.
- When: She clicks "Checkout" and confirms.
- Then: The order is not created, and she sees "Your card was declined. Please try a different payment method."

## API Design

- `POST /api/checkout` — body `{ cardId }`. Returns `201 { orderId }` or `400 CARD_EXPIRED` or `402 PAYMENT_DECLINED`.

## Implementation Plan

- **Sub-task 1** — Checkout endpoint and order creation (INDEPENDENT).
- **Sub-task 2** — Frontend one-click checkout UI (SEQUENTIAL, depends on 1).

## Verification

### Backend tests (per sub-task)

- Sub-task 1: order creation, idempotency, payment gateway error mapping.

### E2E Tests

| Key Scenario                            | Test file              | Assigned sub-task |
| --------------------------------------- | ---------------------- | ----------------- |
| KS-1 One-click checkout with saved card | `e2e/checkout.spec.ts` | 2                 |
