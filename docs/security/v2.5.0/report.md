# Pentest v2.5.0

**Result:** pass
**Mode:** code-level
**Range:** v2.4.3..ed8d207 (24 commits)
**Date:** 2026-10-27

## Findings

| ID | Severity | Category | Where | Description |
| -- | -------- | -------- | ----- | ----------- |
| P1 | low | A01:2025 Broken Access Control | plugins/zuko/scripts/lib/board.py:533 one_slice | a slice name with ../ in a shape's Slices table reads a .md file outside docs/specs into the published board data |

## Assessed

- A01:2025 Broken Access Control — slice names joined into file paths in board.py one_slice and library
- A02:2025 Security Misconfiguration — skill and agent frontmatter, plugin manifest, hooks: no change in range
- A03:2025 Software Supply Chain Failures — no lockfile or manifest change; the board's Mermaid and font loads from a CDN
- A05:2025 Injection — board.py git and gh calls, the board's JSON data slot, the hub's Ideas fragment, fence.py and verify-gates.sh
- A06:2025 Insecure Design — the localhost board server, read only
- A08:2025 Software or Data Integrity Failures — replay-prs.json and gh output parsed as plain data
- A10:2025 Mishandling of Exceptional Conditions — replay errors turn into a note, with no security check on that path

## Not assessed

- A01:2025 Broken Access Control (ownership and role checks) — needs a running server
- A07:2025 Authentication Failures — needs a running server
- A04:2025 Cryptographic Failures — no hashing, signing, tokens or TLS in range
- A09:2025 Security Logging and Alerting Failures — no auth or security event in range
