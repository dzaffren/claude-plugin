# A newline in a grep pattern is two patterns

**Learned:** 2026-11-09 · **From:** /build strix-live

A check wanted `ENDPOINT:` on the line after `FILE:`, and passed
`$'^FILE: …\nENDPOINT: …$'` to `expect_match`. grep reads each line of a
pattern as its own pattern, and matches when any one of them matches. So the
check would pass on text with the `FILE:` line alone, in any order.

## The rule

Never put a newline in an `expect_match` pattern. To check that one line
follows another, take the next line first, as in
`grep -A1 '^FILE: …$' <<<"$out" | tail -n 1`, and match that.
