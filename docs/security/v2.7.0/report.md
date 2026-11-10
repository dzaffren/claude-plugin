# Pentest v2.7.0

**Result:** pass
**Mode:** code-level
**Range:** v2.6.0..400ee48 (6 commits)
**Date:** 2026-11-10

## Findings

| ID | Severity | Category | Where | Description |
| -- | -------- | -------- | ----- | ----------- |
| S1 | medium | A06:2025 Insecure Design (CWE-436) | plugins/zuko/scripts/lib/git-command.py:188 openers_in | Guard parser bypass: heredoc delimiter read as a prefix hides force push, commit on main, attribution and secret-scan commands |
| S2 | medium | A06:2025 Insecure Design (CWE-436) | plugins/zuko/scripts/lib/git-command.py:249 tokenise | Guard parser bypass: git commands inside a double-quoted `$( )` or backticks are invisible to the force-push, commit-on-main, secret-scan and attribution guards |
| S3 | medium | A06:2025 Insecure Design (CWE-436) | plugins/zuko/scripts/lib/git-command.py:441 main | Force-push guard bypass: a newline inside a quoted git argument splits the parsed push line so `+refspec` / `-f` is not matched |
| S4 | medium | A06:2025 Insecure Design (CWE-436) | plugins/zuko/scripts/lib/git-command.py:95 GLOBAL_OPTIONS_WITH_VALUE | Guard parser bypass: unlisted git global options (`--attr-source`, `--config-env`) and attached `-C<dir>` hide the subcommand or the repo directory |
| S5 | low | A06:2025 Insecure Design (CWE-436) | plugins/zuko/scripts/lib/git-command.py:386 where | Guards only recognise a bare `git` word: `/usr/bin/git`, `bash -c`, `eval`, `git -c alias.*` and `git checkout main && git commit` bypass force-push and commit-on-main checks |

## Needs validation

| ID | Category | Where | Description | Unknown |
| -- | -------- | ----- | ----------- | ------- |
| N1 | A05:2025 Injection (CWE-78) | plugins/zuko/scripts/scope-pentester-bash.sh:207 check_git | Strix: Pentester Bash fence bypass: git config and GIT_* env vars run untracked scratch scripts outside the fence | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N2 | A05:2025 Injection (CWE-88) | plugins/zuko/scripts/scope-pentester-bash.sh:285 check_tar | Strix: Pentester Bash fence bypass: `tar --to-command` / `--checkpoint-action=exec` / `--use-compress-program` run arbitrary commands | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N3 | A06:2025 Insecure Design (CWE-184) | plugins/zuko/scripts/scope-pentester-bash.sh:203 check_git | Strix: Pentester Bash fence bypass inside the scratch dir: `git config core.fsmonitor`, PATH shim and rewritten tracked script run arbitrary programs and reach the network | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N4 | A06:2025 Insecure Design (CWE-1286) | plugins/zuko/scripts/block-pentest-target.sh:99 host_port | Strix: Pentest host guard bypass: `#` fragment in a URL makes `host_port` read the wrong host | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N5 | A06:2025 Insecure Design (CWE-184) | plugins/zuko/scripts/block-pentest-target.sh:165 program_of | Strix: Pentest host guard bypass: wrappers with options, piped shells, shell keywords and variable program names hide curl/nc from the guard | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N6 | A01:2025 Broken Access Control (CWE-59) | plugins/zuko/scripts/scope-pentester-bash.sh:437 judge | Strix: Pentester scratch-dir confinement bypass through symlinks from the repository: writes land outside the scratch copy | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N7 | A09:2025 Security Logging and Alerting Failures (CWE-117) | plugins/zuko/scripts/lib/strix.py:254 blocks | Strix: Strix result parser forges report lines: unsanitised finding `id` and OUTSIDE `file` fields accept newlines | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N8 | A06:2025 Insecure Design (CWE-693) | plugins/zuko/scripts/secret-scan.sh:42 module level | Strix: Secret scan before `git commit` misses secrets: `commit -a`, path-limited commits, lines starting with `++`, and `-diff` attributes bypass the staged-diff check | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N9 | A06:2025 Insecure Design (CWE-693) | plugins/zuko/scripts/block-dangerous.sh:48 module level | Strix: Destructive-delete guard misses most recursive deletes of root, system and home paths (`rm -rf /*`, `/home/user`, `$HOME`, `-r -f`, `--recursive`) | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N10 | A08:2025 Software or Data Integrity Failures (CWE-426) | plugins/zuko/scripts/auto-format.sh:12 module level | Strix: Auto-format hook executes a repository-supplied `node_modules/.bin/prettier` on every Write/Edit of a web or doc file | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |
| N11 | A06:2025 Insecure Design (CWE-693) | plugins/zuko/scripts/block-attribution.sh:154 GIT_LABELS | Strix: Attribution guard misses `git commit --trailer`: a Claude co-author trailer can be added without being scanned | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |

## Assessed

- A02:2025 Security Misconfiguration — frontmatter of reviewer.md, review/SKILL.md, ship/SKILL.md: no tools or allowed-tools change; release/SKILL.md allowed-tools (old file)
- A03:2025 Software Supply Chain Failures — suite.yml: 1 CI action added (actions/setup-node@v4.4.0); no lockfile or manifest in the range
- A05:2025 Injection — every python3 call in the hook scripts; spawn calls in cdp.mjs; innerHTML sinks in charts.js; Strix text that reaches the release skill
- A08:2025 Software or Data Integrity Failures — suite.yml trigger and token; tar extraction in strix.py
- A10:2025 Mishandling of Exceptional Conditions — strix.py run-file errors (fail closed through Unreadable)
- Secrets — added lines with key shapes: none
- ATTACK-CLASSES (Cloudflare c1c8a8c) — Injection, Resource and file handling, Obvious things: hook scripts, cdp.mjs, git-command.py, strix.py, suite.yml, design-taste-frontend assets
- AI-AND-LLM (Cloudflare c1c8a8c) — excessive agency and confused-deputy authority, indirect injection: release/SKILL.md, reviewer.md, review/SKILL.md
- SUPPLY-CHAIN-AND-RELEASE (Cloudflare c1c8a8c) — mutable and unbound build inputs, untrusted code in a privileged workflow: suite.yml, windows-suite.yml
- CLIENT-SIDE (Cloudflare c1c8a8c) — DOM-based XSS: charts.js, base.js
- STRIX 1.7.0 (standard, anthropic/claude-sonnet-5-5) — 16 found, 5 confirmed, 11 needs validation · $6.94 of $10

## Not assessed

- A01:2025 Broken Access Control — needs a running server
- A04:2025 Cryptographic Failures — the range adds no hashing, signing, token or TLS code
- A06:2025 Insecure Design — the pentester fence, scope-pentester-bash.sh: not attacked, because it fences this agent and the agent must not test ways out of it; v2.6.0 N7 is still open
- A07:2025 Authentication Failures — needs a running server
- A09:2025 Security Logging and Alerting Failures — the range adds no auth or security event logging
- CLOUD-AND-DEPLOYMENT (Cloudflare c1c8a8c) — no IAM, container or deployment config in the range
- DATA-ISOLATION-AND-LIFECYCLE (Cloudflare c1c8a8c) — no shared store, export or retention code in the range
- DESKTOP-MOBILE-AND-LOCAL-IPC (Cloudflare c1c8a8c) — the range does not change the DevTools socket in cdp.mjs
- MEMORY-SAFETY-AND-BINARY (Cloudflare c1c8a8c) — no native code in the range
- PROTOCOLS-RPC-AND-MESSAGING (Cloudflare c1c8a8c) — no RPC, queue or webhook code in the range
- WEB-PROTOCOL-AND-AUTH (Cloudflare c1c8a8c) — no HTTP server, session or token code in the range

## Files checked

- .github/workflows/suite.yml
- .github/workflows/windows-suite.yml
- plugins/zuko/scripts/auto-format.sh
- plugins/zuko/scripts/block-attribution.sh
- plugins/zuko/scripts/block-dangerous.sh
- plugins/zuko/scripts/block-pentest-target.sh
- plugins/zuko/scripts/check-open-items.sh
- plugins/zuko/scripts/check-skill-pin.sh
- plugins/zuko/scripts/scope-verifier-bash.sh
- plugins/zuko/scripts/secret-scan.sh
- plugins/zuko/scripts/verify-gates.sh
- plugins/zuko/scripts/lib/cdp.mjs
- plugins/zuko/agents/reviewer.md
- plugins/zuko/skills/review/SKILL.md
- plugins/zuko/skills/ship/SKILL.md
- plugins/zuko/scripts/lib/git-command.py
- plugins/zuko/scripts/lib/strix.py
- plugins/zuko/skills/release/SKILL.md
- .agents/skills/design-taste-frontend/README.md
- .agents/skills/design-taste-frontend/assets/base.css
- .agents/skills/design-taste-frontend/assets/base.js
- .agents/skills/design-taste-frontend/assets/charts.js
- .agents/skills/design-taste-frontend/assets/scenes/stage.css
