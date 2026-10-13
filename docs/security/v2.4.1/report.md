# Pentest v2.4.1

**Result:** pass
**Mode:** code-level
**Range:** v2.4.0..3a41acf (28 commits)
**Date:** 2026-10-13

## Findings

| ID  | Severity | Category | Where | Description |
| --- | -------- | -------- | ----- | ----------- |

## Assessed

- A05:2025 Injection — whether git-command.py's comment and heredoc walk matches what bash runs; no shell=True, os.system, eval or string-built command added. One finding was rejected 3 of 3 by the verifiers: the range did not introduce it
- A10:2025 Mishandling of Exceptional Conditions — block-dangerous.sh now blocks on parser exit 3 or 4, so it fails closed
- A01:2025 path traversal — block-attribution.sh opens a -F or --body-file path from the command for reading only, and writes nothing
- A02:2025 Security Misconfiguration — the git-naming.md change is prose only; no frontmatter, permission or hooks.json change
- A03:2025 Software Supply Chain Failures — no lockfile or manifest changed in the range
- Secrets and unsafe file writes — no key-shaped string and no file write added

## Not assessed

- A01:2025 Broken Access Control — no running server; the project is a Claude Code plugin
- A07:2025 Authentication Failures — no running server; the project is a Claude Code plugin
- A05:2025 Injection, `$((...))` and `$[...]` arithmetic forms of the comment walk — the pentester's fence refuses `$`, so they were not run
- A04, A06, A08, A09:2025 — the range touches no crypto, new data flow, deserialisation or security logging
