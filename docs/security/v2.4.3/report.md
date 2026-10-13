# Pentest v2.4.3

**Result:** pass
**Mode:** code-level
**Range:** v2.4.2..c0f0996 (9 commits)
**Date:** 2026-10-13

## Findings

| ID  | Severity | Category | Where | Description |
| --- | -------- | -------- | ----- | ----------- |

## Assessed

- A02:2025 Security Misconfiguration — the ship skill's hunks start below its frontmatter, so allowed-tools is unchanged; no hooks.json, plugin.json, marketplace.json or agent file changed in the range
- A03:2025 Software Supply Chain Failures — no lockfile or manifest changed in the range
- A05:2025 Injection — the only changed code is a test script; the new /ship steps write only files the repo owns and pass the spec path as an argument to verify-ship-gates.sh, which the range does not change; no outside text was added as input to a prompt
- A06:2025 Insecure Design — the hub publish and the status commit moved before the push, into the slice's own PR; no new trust boundary or client-controlled decision
- A08:2025 Software or Data Integrity Failures — no deserialisation, update, plugin-load or CI path changed
- Secrets — no key, token, password or private-key string in the added lines

## Not assessed

- A01:2025 Broken Access Control — needs a running server
- A07:2025 Authentication Failures — needs a running server
- A04:2025 Cryptographic Failures — no hashing, signing, token or TLS code in the range
- A09:2025 Security Logging and Alerting Failures — no logging on an auth or security event changed in the range
- A10:2025 Mishandling of Exceptional Conditions — no error handling changed in the range
- Leak check — the home-directory baseline was denied by the session's permission classifier, so no code ran in the scratch copy; the repo's git status was clean
