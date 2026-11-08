# Pentest v1.5.0

**Result:** pass
**Mode:** code-level
**Range:** v1.4.2..a1b2c3d (9 commits)
**Date:** 2026-10-02

## Findings

| ID  | Severity | Category                                                | Where                                        | Description                         |
| --- | -------- | ------------------------------------------------------- | -------------------------------------------- | ----------------------------------- |
| P1  | medium   | A05:2025 Injection · AI-AND-LLM tool-argument injection | invoice_cli/assistant/tools.py:9 count_lines | a model-chosen path reaches a shell |

## Assessed

- A05:2025 Injection — 1 subprocess call with shell=True, 1 model tool loop
- A03:2025 Software Supply Chain Failures — the range changes no lockfile or manifest
- ATTACK-CLASSES (Cloudflare c1c8a8c) — Injection, Obvious things, Wildcard: invoice_cli/assistant/tools.py, invoice_cli/assistant/loop.py
- AI-AND-LLM (Cloudflare c1c8a8c) — tool-argument injection, excessive agency, indirect injection: invoice_cli/assistant/tools.py, invoice_cli/assistant/loop.py

## Not assessed

- A01:2025 Broken Access Control — needs a running server (slice 5b)
- A07:2025 Authentication Failures — needs a running server (slice 5b)
- CLIENT-SIDE (Cloudflare c1c8a8c) — no browser code in the range
- CLOUD-AND-DEPLOYMENT (Cloudflare c1c8a8c) — no IAM, container or deployment config in the range
- DATA-ISOLATION-AND-LIFECYCLE (Cloudflare c1c8a8c) — no shared store, export or retention code in the range
- DESKTOP-MOBILE-AND-LOCAL-IPC (Cloudflare c1c8a8c) — no native app, deep link or local IPC in the range
- MEMORY-SAFETY-AND-BINARY (Cloudflare c1c8a8c) — no native code in the range
- PROTOCOLS-RPC-AND-MESSAGING (Cloudflare c1c8a8c) — no RPC, queue or webhook code in the range
- SUPPLY-CHAIN-AND-RELEASE (Cloudflare c1c8a8c) — no dependency, CI, release or plugin change in the range
- WEB-PROTOCOL-AND-AUTH (Cloudflare c1c8a8c) — no HTTP, session or token code in the range
