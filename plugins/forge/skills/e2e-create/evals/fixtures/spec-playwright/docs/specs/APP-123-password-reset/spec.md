# APP-123 — Password Reset

## User Story

As a registered user who has forgotten their password, I want to request a reset link by email so that I can regain access to my account without contacting support.

## Acceptance Criteria

- **Given** a registered email, **when** the user submits the forgot-password form, **then** a reset email is sent within 30 seconds.
- **Given** an unregistered email, **when** the user submits the form, **then** the UI shows the same confirmation (no email enumeration).
- **Given** a valid reset link, **when** the user submits a new password meeting strength rules, **then** their password is updated and they are redirected to login.
- **Given** an expired reset link (>1h old), **when** the user visits it, **then** they see an error and a link to request a new one.

## Scope

In scope: email-based password reset for standard accounts.
Out of scope: SSO users, admin-forced resets.

---

## Key Scenarios

**KS-1 — Happy path reset**

- Given: Alice has an account with email `alice@example.com` and has forgotten her password.
- When: She requests a reset, opens the email, follows the link, and sets a new password.
- Then: She can sign in with the new password.

**KS-2 — Expired link**

- Given: Bob requested a reset link over an hour ago and never used it.
- When: He clicks the link now.
- Then: He sees "This reset link has expired" with a button to request a new one.

**KS-3 — Unregistered email**

- Given: An attacker enters `not-a-user@example.com` into the forgot-password form.
- When: They submit.
- Then: They see the same confirmation message ("If an account exists, a reset link has been sent") — no indication of whether the email exists.

## API Design

- `POST /api/auth/forgot-password` — body `{ email }`. Always returns `200 { ok: true }`.
- `POST /api/auth/reset-password` — body `{ token, newPassword }`. Returns `200 { ok: true }` or `400 INVALID_OR_EXPIRED_TOKEN`.

## Implementation Plan

- **Sub-task 1** — Backend endpoints and token model (INDEPENDENT).
- **Sub-task 2** — Frontend forgot-password and reset-password pages (SEQUENTIAL, depends on 1).
- **Sub-task 3** — Email template and sending pipeline (INDEPENDENT).

## Verification

### Backend tests (per sub-task)

- Sub-task 1: token TTL, single-use enforcement, rate limiting.
- Sub-task 3: email template renders with correct reset URL.

### E2E Tests

| Key Scenario            | Test file                    | Assigned sub-task |
| ----------------------- | ---------------------------- | ----------------- |
| KS-1 Happy path reset   | `e2e/password-reset.spec.ts` | 2                 |
| KS-2 Expired link       | `e2e/password-reset.spec.ts` | 2                 |
| KS-3 Unregistered email | `e2e/password-reset.spec.ts` | 2                 |
