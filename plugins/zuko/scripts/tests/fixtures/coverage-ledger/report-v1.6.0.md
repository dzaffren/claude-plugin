# Pentest v1.6.0

**Result:** pass
**Mode:** code-level
**Range:** v1.5.0..b2c3d4e (1 commit)
**Date:** 2026-10-09

## Findings

| ID  | Severity | Category | Where | Description |
| --- | -------- | -------- | ----- | ----------- |

## Needs validation

| ID  | Category | Where | Description | Unknown |
| --- | -------- | ----- | ----------- | ------- |

## Assessed

- A01:2025 Broken Access Control — 2 file paths built from CSV fields
- A05:2025 Injection — 3 subprocess calls, 2 SQL strings

## Not assessed

- A07:2025 Authentication Failures — needs a running server (slice 5b)

## Files checked

- invoice_cli/cli.py
- invoice_cli/exporters/csv.py
- invoice_cli/exporters/suppliers.py
- invoice_cli/importers/bank.py
- invoice_cli/importers/statement.py
- invoice_cli/ledger.py
