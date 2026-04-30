WROTE: e2e/password-reset.spec.ts
Scenarios covered:

- KS-1: user can recover a forgotten password (request reset, follow email link, set new password, sign in with new password)
- KS-2: user sees an expired-link message when opening a stale reset link
- KS-3: forgot-password form shows the same confirmation for an unregistered email (no enumeration)
  Framework: playwright
  Next: invoke the `e2e` skill to run the suite.

NOTE: Introduced new test scaffolding that the repo does not yet have an exemplar for:

- An inline helper `getResetLinkFromTestInbox(email)` that reads from `GET /api/test/inbox?email=...`. Needed for KS-1 because the happy path requires the reset URL delivered by email — without a test mailbox, the journey cannot be exercised end-to-end.
- A test-only seeding call to `POST /api/test/reset-tokens` with an `ageSeconds` parameter to mint a pre-expired token for KS-2. Without this, KS-2 would require a hard sleep of >1 hour, which is not acceptable.
  Both endpoints belong to the backend (sub-task 1) / email pipeline (sub-task 3) team to provide in non-production environments. If the project prefers a different test mailbox or token-seeding mechanism, swap these two call sites.

NOTE: The spec's E2E table does not cover a scenario for "password fails strength rules" on the reset page — that's likely intentional (belongs in integration/unit tests), but flagging in case prd-refine should revisit.
