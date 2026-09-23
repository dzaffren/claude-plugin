# A gate names the one state that passes

**Learned:** 2026-09-24 · **From:** auto-onboard review (finding G1)

The new overview check blocked `Draft` and an empty status, and let everything
else through. So `**Status:** draft` in lowercase, or any typo, counted as
approved. The same review found a second fail-open path in the same block: a
row inside a fenced code example counted as the real row.

This is the third gate in this repo that failed open. The first was
`gate-scanned-nothing-is-not-a-pass.md`. The second was ship-naming's
"close the fail-open paths" fix.

## The rule

When a gate branches on a value, the passing branch matches the one allowed
value exactly. The catch-all branch fails and names what it found. Listing the
bad values leaves every unlisted value as a pass.

Also test one input that is almost right: wrong case, inside a code fence, a
near-miss name. A gate's tests should try to make it pass wrongly, not only
check that it fails correctly.
