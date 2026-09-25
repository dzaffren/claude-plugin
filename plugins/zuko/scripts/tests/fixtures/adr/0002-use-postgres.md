---
status: accepted
date: 2025-03-09
---

# Use Postgres

## Context and Problem Statement

Two finance users import invoices at month end at the same time. The store must take
concurrent writes without locking the whole database. It also has to run on the shared
server.

## Considered Options

* Postgres
* SQLite
* DynamoDB

## Decision Outcome

Chosen option: "Postgres", because it takes row-level locks and we already run it.

## Pros and Cons of the Options

### Postgres

* Good, because row-level locking
* Bad, because one more server to run

### SQLite

* Good, because no server
* Bad, because it locks the whole file on write

### DynamoDB

* Good, because managed
* Bad, because it costs more than the server for under 1 GB of data
