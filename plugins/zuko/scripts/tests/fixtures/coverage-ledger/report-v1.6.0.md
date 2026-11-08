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

- A01:2025 Broken Access Control — 1 file path built from a CSV field
- A05:2025 Injection — 2 subprocess calls, 1 SQL string

## Not assessed

- A07:2025 Authentication Failures — needs a running server (slice 5b)

## Files checked

- invoice_cli/exporters/ledger.py
- invoice_cli/importers/bank.py
- invoice_cli/cli.py
- invoice_cli/importers/__init__.py
- invoice_cli/importers/ocr.py
- invoice_cli/importers/statement.py
- invoice_cli/money.py
- invoice_cli/paths.py
- invoice_cli/report.py
- invoice_cli/rounding.py
- invoice_cli/suppliers.py
- invoice_cli/tax.py
