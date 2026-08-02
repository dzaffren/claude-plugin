---
name: security
description: >
  Security review of the current branch's changes after /quality. Use when
  the user says "security check", "security review", "scan for
  vulnerabilities". Defensive review of the diff: secrets, injection, authz,
  unsafe deps. Reports findings with severity; fixes only with approval.
---

# Security

Review the branch's diff for vulnerabilities introduced or exposed by this
change. Scope is the diff and what it touches — not a whole-repo audit unless
asked.

## Steps

1. **Get the diff** (`git diff main...HEAD`) and the list of changed files.

2. **Scan for secrets first.** In the diff AND the branch's commit history
   (`git log -p main...HEAD`): keys, tokens, passwords, connection strings,
   real customer or production data. A secret in an earlier commit is still
   leaked even if a later commit removes it — flag it for history rewrite
   before any push.

3. **Review the changes** against the classes that actually apply to this
   diff (skip the rest):
   - **Injection** — SQL/command/path/template built from user input without
     parameterization or escaping.
   - **AuthN/AuthZ** — new endpoints or handlers missing the auth checks
     their siblings have; object-level access (can user A reach user B's
     record by changing an ID?).
   - **Input validation** — external input trusted for size, type, or range;
     deserialization of untrusted data.
   - **Data exposure** — sensitive fields in logs, error messages, or API
     responses that didn't leak before.
   - **Dependencies** — new packages: known-vulnerable versions, typosquats,
     unmaintained. Check the lockfile diff, not just the manifest.
   - **Crypto & transport** — home-rolled crypto, http where https existed,
     weakened TLS or cookie flags.

4. **Verify each finding** by reading the code and tracing the input path
   for real. Rate what survives: Critical / High / Medium / Low, each with
   the file:line and a one-line attack scenario.

5. **Report and wait.** Findings with severity, or a clean bill stating what
   was checked. Fix only with the user's go-ahead — security fixes can change
   behavior. Next step once clear: `/ship`.
