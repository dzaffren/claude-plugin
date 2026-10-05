# Pentest v2.2.0

**Result:** pass
**Mode:** code-level
**Range:** whole tree at d46abeb (405 commits, first release)
**Date:** 2026-10-05

## Findings

| ID  | Severity | Category                                       | Where                                                              | Description                                                                                        |
| --- | -------- | ---------------------------------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| P1  | medium   | A06:2025 Insecure Design                       | plugins/zuko/scripts/scope-pentester-bash.sh:235 SCRATCH_TOOLS     | the pentester fence allows awk, and awk's system() runs programs and paths the fence refuses       |
| P2  | low      | A05:2025 Injection                             | plugins/zuko/scripts/check-design-drift.sh:73 raw-hex-colour check | scanned file names go into a sed program unescaped, so a crafted name makes sed write a file       |
| P3  | low      | A10:2025 Mishandling of Exceptional Conditions | plugins/zuko/scripts/block-dangerous.sh:6 command extraction       | a command the JSON parser rejects exits 0, so a force push holding a lone surrogate is not blocked |
| P4  | low      | A10:2025 Mishandling of Exceptional Conditions | plugins/zuko/scripts/secret-scan.sh:6 command extraction           | a git commit the JSON parser rejects exits 0 before the staged diff is scanned                     |

## Assessed

- A02:2025 Security Misconfiguration — tools and allowed-tools frontmatter of 4 agents and 12 skills, plugin.json, marketplace.json, hooks.json
- A03:2025 Software Supply Chain Failures — skills-lock.json; no other lockfile or manifest
- A05:2025 Injection — shell=True, os.system, eval and bash -c across scripts/ and lib/; sed and awk programs built from variables; path joins and file writes in lib/*.py
- A06:2025 Insecure Design — the pentester and verifier Bash fences, run live through the active hook
- A10:2025 Mishandling of Exceptional Conditions — the `|| exit 0` error paths in the PreToolUse guard hooks
- Secrets — whole tree grepped for key prefixes and credential assignments

## Not assessed

- A01:2025 Broken Access Control — no running server; the project is a Claude Code plugin
- A07:2025 Authentication Failures — no running server; the project is a Claude Code plugin
- A04:2025 Cryptographic Failures — no hashing, signing, token or TLS code
- A08:2025 Software or Data Integrity Failures — no deserialisation beyond json; no CI workflow
- A09:2025 Security Logging and Alerting Failures — no auth or security event logging
- A05:2025 Injection (untrusted repo text steering a skill's tool call) — proving it needs a live model session
