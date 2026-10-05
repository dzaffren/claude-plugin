# Recompute a spec's backfill list with the built check

**Learned:** 2026-10-05 · **From:** glossary-gate build

The glossary-gate spec listed, from a hand run on 2026-09-25, the live docs
the new check would fail and the terms each needed. Ten days later at
`/build`, ten of those specs had shipped and dropped out of scope, and the
real helper found five terms the hand run missed in the spec itself
(lockfile, pentest, OWASP, XSS, SARIF). It also refused `- **OWASP Top 10**`
as an entry for OWASP, which the hand run had accepted.

## The rule

Treat a spec's backfill list as a guess. Write the check first, run it over
the repo's live docs, and backfill exactly what it prints. Check untracked
docs in the main checkout too: they are not on the branch, but the gate
reads them there after the merge.
