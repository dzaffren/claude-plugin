# Spec: Add User Profile

Allow users to retrieve and update their profile (display name, bio, avatar URL).

## Architecture Decision
- `src/controllers/users.controller.ts` — existing users controller
- `src/services/users.service.ts` — existing users service
- `src/db/schema.sql` — DB schema reference

## Exemplar
`src/controllers/tasks.controller.ts`

## Implementation Plan

### Task 1 — Add profile columns to users table [SEQUENTIAL]
Add `display_name`, `bio`, `avatar_url` columns to the users table migration.
Acceptance: Migration file exists at `src/db/migrations/add_profile_fields.sql`.

### Task 2 — Implement GET /users/:id/profile endpoint [SEQUENTIAL]
Add controller + service method to fetch user profile fields.
Acceptance: `GET /users/123/profile` returns `{display_name, bio, avatar_url}`.

### Task 3 — Implement PATCH /users/:id/profile endpoint [SEQUENTIAL]
Add controller + service method to update profile fields.
Acceptance: `PATCH /users/123/profile` with body updates the user record and returns updated profile.
