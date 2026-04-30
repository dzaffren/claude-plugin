# Project: Task Tracker API

A Node.js/Express REST API for managing tasks.

## Stack
- Node.js 20, Express 5, TypeScript
- PostgreSQL via pg-promise
- Jest for tests

## Conventions
- Controllers in `src/controllers/`
- Services in `src/services/`
- Tests mirror src structure under `tests/`
- Use async/await; no callbacks
- Exemplar: `src/controllers/tasks.controller.ts`

## Commands
- `npm test` — run Jest
- `npm run lint` — ESLint
- `npm run build` — tsc
