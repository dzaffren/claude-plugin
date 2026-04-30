# Acme Web

## Stack

- TypeScript, Next.js 14 App Router
- Vitest for tests
- Prisma + Postgres
- Playwright for E2E

## Commands

- `pnpm dev` — local dev server
- `pnpm test` — unit tests
- `pnpm e2e` — end-to-end tests
- `pnpm lint` — eslint + prettier check

## Conventions

- Run `pnpm lint` before committing.
- Keep files under 300 lines.

## Learnings

- **prd-refine missing migration sub-tasks** — when a plan touches a model file, always include a matching database migration sub-task in the Implementation Plan. See `docs/learnings/skill-prd-refine-missing-migrations.md`.
