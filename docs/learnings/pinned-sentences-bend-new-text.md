# A test that pins a prompt sentence word for word bends the next edit around it

**Learned:** 2026-10-26 · **From:** /build gate-card

`test-idea-board.sh` and `test-pause-questions.sh` match whole sentences of
`skills/spec/SKILL.md`, including what follows `**Then stop.**`. The gate-card
chunk could not put its new print where it belonged without breaking them, so
pause 1 ended up with a different order from pauses 2 and 3.

Wrong: let a chunk work around a pinned sentence it does not own. Right: when
a plan changes text that another test pins, name that test in the chunk's
files, so the chunk can loosen the check to the fact it guards.
