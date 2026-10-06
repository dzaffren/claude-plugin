# Pentest v2.3.0

**Result:** pass
**Mode:** code-level
**Range:** v2.2.0..621c3a5 (27 commits)
**Date:** 2026-10-06

## Findings

| ID  | Severity | Category           | Where                                                    | Description                                                                                                                                                    |
| --- | -------- | ------------------ | -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P1  | low      | A05:2025 Injection | plugins/zuko/scripts/lib/release-commit.py:64 whole_call | the release-commit check accepts a brace-expansion token in a -m value, so the shell can expand it into extra git options on a commit the guard lets onto main |

## Assessed

- A05:2025 Injection — release-commit.py whole_call against shell expansion; check-design-drift.sh file-name handling; no shell=True, os.system or eval added in the range
- A06:2025 Insecure Design — the release marker that lets one commit onto main past block-dangerous.sh
- A10:2025 Mishandling of Exceptional Conditions — hook payload parse failures in 3 hooks now block; release-commit.py denial exit codes
- A02:2025 Security Misconfiguration — release SKILL.md body change only; the pentester fence allow-lists only got narrower
- A03:2025 Software Supply Chain Failures — no lockfile or manifest changed in the range
- Secrets — added lines grepped for key, token, password and private-key patterns

## Not assessed

- A01:2025 Broken Access Control — no running server; the project is a Claude Code plugin
- A07:2025 Authentication Failures — no running server; the project is a Claude Code plugin
- A04:2025 Cryptographic Failures — no hashing, signing, tokens or TLS in the range
- A08:2025 Software or Data Integrity Failures — no deserialisation, update loading or CI change in the range
- A09:2025 Security Logging and Alerting Failures — no logging on auth or security events added or removed
