# 4. Cron for imports

Date: 2025-04-01

## Status

Superseded by [ADR-0006](0006-queue-for-imports.md)

## Context

Imports run on the first and fifteenth of each month. A cron job on the server can
start them. Nothing else needs scheduling.

## Decision

A cron entry on the server starts each import.

## Consequences

A failed import waits for someone to notice.
