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

- **Use Vitest, not Jest** — we migrated last quarter; Jest config only remains for one legacy package. See `.claude/learnings/convention-use-vitest.md`.
