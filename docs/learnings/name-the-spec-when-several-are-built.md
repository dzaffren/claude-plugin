# Name the spec when several are Built

**Learned:** 2026-10-05 · **From:** /ship ascii-terminal

`verify-ship-gates.sh` with no argument gates the first spec at `Built` it
finds. After design-system merged but before its close-out, `main` carried
it as Built, so the gate on the ascii-terminal branch checked design-system's
row and passed for the wrong slice.

## The rule

When more than one slice is in flight, run
`verify-ship-gates.sh docs/specs/{slice}.md` with the path, and read the
`Spec:` line it prints before trusting the pass.
