# Spec: Magic Link Authentication

Add passwordless email login via magic links.

## Backend Scope

### Architecture Decision
- `app/routes/sessions.py` — session routes
- `app/services/email.py` — email sending service
- `app/models/token.py` — token model

### Exemplar
`app/routes/sessions.py`

### Implementation Plan

#### Task 1 — Token generation and storage [INDEPENDENT]
Generate a short-lived signed token and persist it.
Acceptance: `POST /auth/magic-link` creates a token record in the DB with 15min TTL.

#### Task 2 — Email dispatch [INDEPENDENT]
Send the magic link to the user's email.
Acceptance: Calling the send_magic_link service method triggers email via the email service.

#### Task 3 — Token verification endpoint [SEQUENTIAL]
Validate the token and issue a session.
Acceptance: `GET /auth/verify?token=<tok>` returns a session JWT if the token is valid and unexpired.

## Frontend Scope

### Architecture Decision
- `src/pages/Login.tsx`
- `src/components/MagicLinkForm.tsx`

### Exemplar
`src/pages/Settings.tsx`

### Implementation Plan

#### Task 1 — Magic link form [INDEPENDENT]
Build the email input form that calls the backend.
Acceptance: Form renders, validates email, and shows success message after submission.
