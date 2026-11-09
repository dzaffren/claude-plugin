# Pentest v2.6.0

**Result:** pass
**Mode:** code-level
**Range:** v2.5.1..9d9b957 (16 commits)
**Date:** 2026-11-09

## Findings

| ID | Severity | Category | Where | Description |
| -- | -------- | -------- | ----- | ----------- |
| P1 | low | A01:2025 Broken Access Control · ATTACK-CLASSES Resource and file handling | plugins/zuko/scripts/scope-pentester-bash.sh:427 module level | The fence judges each word with `\` turned into `/`, so on Linux and macOS it allows a write to a path outside the scratch dir that starts with the scratch dir's name followed by a backslash |
| P2 | low | A03:2025 Software Supply Chain Failures | skills-lock.json:9 skills.design-taste-frontend | The range changes the design-taste-frontend entry in skills-lock.json: the vendored skill's hash changes and the entry gains a tag pin |
| S1 | low | A01:2025 Broken Access Control (CWE-59) | .agents/skills/design-taste-frontend/scripts/inspect.mjs:55 request handler | Inspector/scenes preview server follows symlinks and serves the whole working directory, letting a previewed page read and exfiltrate local files |
| S2 | low | A01:2025 Broken Access Control (CWE-22) | .agents/skills/design-taste-frontend/scripts/scenes.mjs:63 SCENES | Page-controlled scene id used unsanitized in output file path (arbitrary-location JPEG write) and in helper-page HTML in scenes.mjs |

## Needs validation

| ID | Category | Where | Description | Unknown |
| -- | -------- | ----- | ----------- | ------- |
| N1 | A02:2025 Security Misconfiguration (CWE-250) | plugins/zuko/skills/release/SKILL.md:10 allowed-tools | Strix: Release skill pre-approves unrestricted bash, curl, python3, tar and kill, removing the permission prompt for prompt-injected commands | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N2 | A06:2025 Insecure Design (CWE-184) | plugins/zuko/scripts/block-pentest-target.sh:165 program_of | Strix: Pentest-target guard bypassed by wrapper commands that take arguments (timeout, env, nice, sudo) | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N3 | A06:2025 Insecure Design (CWE-1286) | plugins/zuko/scripts/block-pentest-target.sh:99 host_port | Strix: Pentest-target guard accepts `#@target` and header-borne target URLs while curl reaches another host | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N4 | A06:2025 Insecure Design (CWE-693) | plugins/zuko/scripts/block-pentest-target.sh:122 NET | Strix: Pentest-target guard only recognises seven tool names; other egress channels, quoted substitutions and shell compounds pass | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N5 | A05:2025 Injection (CWE-78) | plugins/zuko/scripts/scope-pentester-bash.sh:291 check_tar | Strix: Pentester fence allows tar options that execute arbitrary programs (--to-command, --checkpoint-action, -I) | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N6 | A06:2025 Insecure Design (CWE-693) | plugins/zuko/scripts/scope-pentester-bash.sh:210 check_git | Strix: Pentester fence applies no git restrictions inside the scratch copy (network subcommands, config-triggered execution, writes outside the copy) | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N7 | A06:2025 Insecure Design (CWE-367) | plugins/zuko/scripts/scope-pentester-bash.sh:255 tracked | Strix: Pentester fence's "tracked script only" rule is defeated by overwriting the tracked file in the scratch copy first | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N8 | A06:2025 Insecure Design (CWE-184) | plugins/zuko/scripts/lib/git-command.py:386 invocations_with_dirs | Strix: Force-push and commit-on-main guard only sees a bare `git` word; `/usr/bin/git`, `bash -c`, `eval` and variables bypass it | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N9 | A06:2025 Insecure Design (CWE-184) | plugins/zuko/scripts/block-dangerous.sh:36 module level | Strix: Commit-on-main and force-push guard matches subcommand names only; git aliases, merge/cherry-pick/rebase and push-config bypass it | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N10 | A06:2025 Insecure Design (CWE-184) | plugins/zuko/scripts/block-dangerous.sh:48 module level | Strix: Recursive-delete guard misses split flags, long options, trailing slashes, $HOME and quoted paths | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N11 | A06:2025 Insecure Design (CWE-693) | plugins/zuko/scripts/secret-scan.sh:42 module level | Strix: Secret scan before commit inspects only staged changes, so `git commit -a` and `git commit <path>` skip it | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N12 | A06:2025 Insecure Design (CWE-184) | plugins/zuko/scripts/block-attribution.sh:154 read_options | Strix: Attribution guard does not read `git commit --trailer`, `git merge -m` or other message-bearing commands | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N13 | A01:2025 Broken Access Control (CWE-22) | plugins/zuko/scripts/lib/strix.py:171 copy_head | Strix: Arbitrary file write via tar extraction fallback in Strix release-pentest copy (Python without tarfile filters) | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N14 | A06:2025 Insecure Design (CWE-693) | plugins/zuko/scripts/lib/cdp.mjs:88 launch | Strix: Rendered drift gate's no-egress guard is bypassed by WebRTC UDP, so a previewed page can send data off the machine | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |

## Assessed

- A01:2025 Broken Access Control (path traversal only) — scratch-path checks in scope-pentester-bash.sh; path joins in strix.py, coverage.py, rendered-drift.mjs
- A02:2025 Security Misconfiguration — frontmatter of pentester.md, finding-verifier.md and 5 skills: no tools or allowed-tools change; plugin.json adds license only
- A03:2025 Software Supply Chain Failures — skills-lock.json: 1 entry changed; strix.py: strix-agent==1.7.0 installed by uv on request; windows-suite.yml: 2 actions pinned by tag, push and dispatch trigger, contents: read, no secrets
- A05:2025 Injection — every subprocess call added or changed in the range (argument lists, no shell=True); Strix output that reaches release.py and the release skill
- A06:2025 Insecure Design — the pentester fence; the coverage ledger's trust in Files checked
- A08:2025 Software or Data Integrity Failures — tar extraction in strix.py; JSON parsing of Strix run files; new CI workflow
- A10:2025 Mishandling of Exceptional Conditions — strix.py findings and report, coverage.read, check-attack-pin.sh and check-skill-pin.sh (notice only)
- Secrets — added lines with key shapes: only test fixtures and the AWS documentation example key
- ATTACK-CLASSES (Cloudflare c1c8a8c) — Injection, Access control, Resource and file handling, Obvious things: scope-pentester-bash.sh, strix.py, release.py, coverage.py, program.py, git-command.py, block-attribution.sh, cdp.mjs, rendered-drift.mjs, skills-lock.json, migrate-radix-to-base old files
- AI-AND-LLM (Cloudflare c1c8a8c) — excessive agency and confused-deputy authority, tool-argument injection, sub-agent trust inheritance: scope-pentester-bash.sh, strix.py, pentester.md
- SUPPLY-CHAIN-AND-RELEASE (Cloudflare c1c8a8c) — mutable and unbound build inputs, untrusted code in a privileged workflow: skills-lock.json, windows-suite.yml, strix.py install
- CLIENT-SIDE (Cloudflare c1c8a8c) — DOM-based XSS, client-side navigation: rendered-drift.mjs, cdp.mjs
- STRIX 1.7.0 (standard, anthropic/claude-sonnet-5-5) — 17 found, 2 confirmed, 14 needs validation, 1 outside · $8.75 of $10

## Not assessed

- A01:2025 Broken Access Control (ownership and role checks) — needs a running server
- A07:2025 Authentication Failures — needs a running server
- A04:2025 Cryptographic Failures — the range adds no hashing, signing, token generation or TLS code
- A09:2025 Security Logging and Alerting Failures — the range adds no auth or security event logging
- CLOUD-AND-DEPLOYMENT (Cloudflare c1c8a8c) — no IAM, container or deployment config in the range; Strix's Docker sandbox is not configured by zuko
- DATA-ISOLATION-AND-LIFECYCLE (Cloudflare c1c8a8c) — no shared store or tenant data; the coverage ledger is one file in one repo
- DESKTOP-MOBILE-AND-LOCAL-IPC (Cloudflare c1c8a8c) — not read; the only local IPC is a DevTools socket on a random loopback port to a headless Chrome
- MEMORY-SAFETY-AND-BINARY (Cloudflare c1c8a8c) — no native code in the range
- PROTOCOLS-RPC-AND-MESSAGING (Cloudflare c1c8a8c) — no RPC server, queue or webhook in the range
- WEB-PROTOCOL-AND-AUTH (Cloudflare c1c8a8c) — no HTTP server, session or token code in the range

## Files checked

- plugins/zuko/scripts/scope-pentester-bash.sh
- plugins/zuko/scripts/lib/strix.py
- plugins/zuko/scripts/lib/coverage.py
- plugins/zuko/scripts/lib/release.py
- plugins/zuko/scripts/lib/program.py
- plugins/zuko/scripts/lib/git-command.py
- plugins/zuko/scripts/lib/fence.py
- plugins/zuko/scripts/lib/release-commit.py
- plugins/zuko/scripts/lib/stop_scope.py
- plugins/zuko/scripts/lib/board.py
- plugins/zuko/scripts/lib/changelog.py
- plugins/zuko/scripts/lib/decisions.py
- plugins/zuko/scripts/lib/glossary.py
- plugins/zuko/scripts/lib/pr_body.py
- plugins/zuko/scripts/lib/readme_block.py
- plugins/zuko/scripts/lib/cdp.mjs
- plugins/zuko/scripts/lib/rendered-drift.mjs
- plugins/zuko/scripts/lib/token-files.sh
- plugins/zuko/scripts/block-attribution.sh
- plugins/zuko/scripts/block-dangerous.sh
- plugins/zuko/scripts/block-pentest-target.sh
- plugins/zuko/scripts/scope-verifier-bash.sh
- plugins/zuko/scripts/check-attack-pin.sh
- plugins/zuko/scripts/check-skill-pin.sh
- plugins/zuko/scripts/check-rendered-drift.sh
- plugins/zuko/scripts/check-design-drift.sh
- plugins/zuko/scripts/check-open-items.sh
- plugins/zuko/scripts/secret-scan.sh
- plugins/zuko/scripts/auto-format.sh
- plugins/zuko/scripts/verify-gates.sh
- plugins/zuko/agents/pentester.md
- plugins/zuko/.claude-plugin/plugin.json
- skills-lock.json
- .github/workflows/windows-suite.yml
- .gitattributes
- .agents/skills/migrate-radix-to-base/SKILL.md
- .agents/skills/migrate-radix-to-base/class-mapping.md
- .agents/skills/migrate-radix-to-base/consumer-props.md
- .agents/skills/migrate-radix-to-base/wrapper-shapes.md
- .agents/skills/migrate-radix-to-base/universal-patterns.md
- .agents/skills/migrate-radix-to-base/disclosure.md
- .agents/skills/migrate-radix-to-base/form-controls.md
