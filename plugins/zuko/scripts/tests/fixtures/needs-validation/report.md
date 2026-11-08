# Pentest v1.5.0

**Result:** pass
**Mode:** code-level
**Range:** v1.4.2..a1b2c3d (9 commits)
**Date:** 2026-10-02

## Findings

| ID  | Severity | Category           | Where                                              | Description                                  |
| --- | -------- | ------------------ | -------------------------------------------------- | -------------------------------------------- |
| P1  | medium   | A05:2025 Injection | invoice_cli/importers/statement.py:18 parse_period | a statement field reaches ORDER BY unchecked |

## Needs validation

| ID  | Category                                           | Where                                                  | Description                                                              | Unknown                                                                                     |
| --- | -------------------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| N1  | A05:2025 Injection                                 | invoice_cli/exporters/suppliers.py:29 export_suppliers | on Windows, a supplier name may reach a cmd.exe shell string unquoted    | whether cmd.exe on Windows runs the text after & in a supplier name as its own command      |
| N2  | A02:2025 Security Misconfiguration                 | .github/workflows/release.yml:14 publish               | the release job may push to main without a review                        | whether branch protection on acme/invoice-cli requires a review before a push to main       |
| N3  | A05:2025 Injection · AI-AND-LLM indirect injection | invoice_cli/assistant/loop.py:22 run_tools             | invoice text in the prompt may steer write_note to a path outside notes/ | whether the model obeys an instruction in invoice text to call write_note with another path |

## Assessed

- A01:2025 Broken Access Control — 1 file path built from a CSV field
- A02:2025 Security Misconfiguration — .github/workflows/release.yml
- A05:2025 Injection — 2 subprocess calls, 1 SQL string, 1 model tool loop
- ATTACK-CLASSES (Cloudflare c1c8a8c) — Injection, Obvious things: invoice_cli/exporters/suppliers.py, invoice_cli/importers/statement.py
- AI-AND-LLM (Cloudflare c1c8a8c) — indirect injection, excessive agency: invoice_cli/assistant/loop.py

## Not assessed

- A07:2025 Authentication Failures — needs a running server (slice 5b)
- CLIENT-SIDE (Cloudflare c1c8a8c) — no browser code in the range
- MEMORY-SAFETY-AND-BINARY (Cloudflare c1c8a8c) — no native code in the range
