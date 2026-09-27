# A spec drafted before its dependency finished can rest on a premise that build changed

**Learned:** 2026-09-27 · **From:** /build regression-review

regression-review (7b) was specced on 2026-09-25 while owasp-lens (7a) was still
building. Its plan and drafted D14 said "the verifier stays without Bash". 7a's
build then gave the verifier hook-scoped read-only git (D8, then D9). The open
items gate passed — every row was closed — and recording D14 as drafted would
have put an entry into `DECISIONS.md` that contradicts an active one.

## The rule

At the build gate, before recording a spec's drafted decisions, read the
active entries (`scripts/lib/decisions.py active .`) added since the spec was
written, and check each drafted entry and each "X has no Y" premise in the
plan against them. A contradiction is a ledger row and a question, not a
silent redraft.
