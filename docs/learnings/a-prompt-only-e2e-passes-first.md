# A prompt-only slice's e2e passes before the change

**Learned:** 2026-10-13 · **From:** /build shipped-in-pr

`shipped-in-pr` moved /ship's writes before the push. Only skill text changed.
The e2e walk in `test-shipped-in-pr.sh` passed all 31 of its checks before
the edit, because `block-dangerous.sh`, the ship gate and the renderer
already allowed the new order. The 22 text checks were the tests that failed
first.

## The rule

When a slice changes only prompt text, the text checks are the red tests.
The e2e proves the scripts and hooks allow the new flow, so it may pass from
the start. Say so in the build report, so nobody reads a green e2e as an
untested one.
