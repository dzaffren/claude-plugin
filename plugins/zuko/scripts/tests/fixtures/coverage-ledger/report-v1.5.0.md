# Pentest v1.5.0

**Result:** pass
**Mode:** code-level
**Range:** v1.4.2..a1b2c3d (1 commit)
**Date:** 2026-10-02

## Findings

| ID  | Severity | Category | Where | Description |
| --- | -------- | -------- | ----- | ----------- |

## Needs validation

| ID  | Category           | Where                      | Description                                          | Unknown                                              |
| --- | ------------------ | -------------------------- | ---------------------------------------------------- | ---------------------------------------------------- |
| N1  | A05:2025 Injection | invoice_cli/cli.py:12 main | on Windows, a folder name may reach a shell unquoted | whether cmd.exe on Windows splits a folder name at & |

## Assessed

- A01:2025 Broken Access Control — 1 file path built from a CSV field
- A05:2025 Injection — 2 subprocess calls, 1 SQL string

## Not assessed

- A07:2025 Authentication Failures — needs a running server (slice 5b)

## Files checked

- check.sh
- invoice_cli/__init__.py
- invoice_cli/cli.py
- invoice_cli/exporters/suppliers.py
