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

1. **Size the review.** `git diff --stat main...HEAD` and the changed file
   list. Small diff (≤5 files and ≤300 changed lines) → one
   `security-reviewer`, one `finding-verifier` per finding. Larger → full
   shape: reviewer plus a three-lens verifier panel per finding. Breadth
   scales with the diff; the verification bar never does.

2. **Use real tooling when installed.** If the Trail of Bits skills are
   available (`static-analysis`, `differential-review` — from
   `trailofbits/skills`), run them on the diff first and treat their output
   as candidate findings for step 5's verification. Absent → prompt-only
   review as below.

3. **Spawn the `security-reviewer` agent** with the diff range — it's
   read-only and covers the classes below, verifying each candidate by
   tracing the input path. Steps 3–4 describe what it checks and how you
   validate its report; do the secrets history check yourself as well, it's
   too important to delegate blindly.

4. **Scan for secrets first.** In the diff AND the branch's commit history
   (`git log -p main...HEAD`): keys, tokens, passwords, connection strings,
   real customer or production data. A secret in an earlier commit is still
   leaked even if a later commit removes it — flag it for history rewrite
   before any push.

5. **Review the changes** against the classes that actually apply to this
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

6. **Verify adversarially.** For each candidate finding (from the tools,
   the reviewer agent, or your own pass), spawn `finding-verifier` agents —
   count and lenses from step 1 (panel lenses: reachability, impact,
   defenses; all findings' verifiers in parallel). Pass ONLY the bare claim
   (`file:line · category · one-line attack scenario`) and the diff range,
   never the finder's reasoning. Survives on TRUE_POSITIVE from the single
   verifier, or 2-of-3 on the panel. Rate survivors Critical / High /
   Medium / Low.

7. **Capture lessons automatically** (learn skill). A recurring unsafe
   pattern or a repo-specific security convention becomes a lesson in
   `docs/learnings/`, written without asking.

8. **Report and wait.** Findings with severity, or a clean bill stating what
   was checked. Fix only with the user's go-ahead — security fixes can change
   behavior. Next step once clear: `/ship`.
