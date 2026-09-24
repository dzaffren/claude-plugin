---
number: 0006
title: Queue for imports
status: Accepted
date: 2025-05-10
supersedes: 0004
superseded-by:
---

# 0006. Queue for imports

## Status

Accepted

## Context

A failed cron import sat unnoticed for nine days in April. Imports need retries and an
alert when they fail. The team compared a queue with a smarter cron wrapper.

## Decision

Imports go through a Redis-backed job queue with three retries.

## Alternatives

* Cron with a retry wrapper: no alerting, and the wrapper grows into a queue anyway.

## Consequences

Redis joins the stack.
