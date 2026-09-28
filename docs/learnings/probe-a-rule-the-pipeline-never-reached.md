# A verifier rule the reviewer pre-empts never fires in the seeded run

**Learned:** 2026-09-27 · **From:** /build regression-review

Scenario 3 wanted a verifier to reject a regex-guarded injection twin with
`DEFENCE: routes/reports.py:12`. In the seeded `/review` the reviewer read the
guard itself and never raised the twin, so no verifier saw it. The end-to-end
run could not show the rule either way.

## The rule

When a scenario tests the verifier's judgement on a finding the reviewer may
legitimately filter, prove the verifier rule with a direct probe: one headless
`claude -p` that dispatches `zuko:finding-verifier` with only the fields the
skill passes (claim, CATEGORY, SEVERITY, FILE, SYMBOL, SNIPPET, CHANGE, BASE),
in the seeded repo. Record both the run and the probe. Do not re-run the whole
review hoping the reviewer gets it wrong.
