# A section helper stops at a heading inside a code fence

**Learned:** 2026-10-12 · **From:** /build unattended-build

The tests' `section()` helper reads the lines under one `## ` heading, up to
the next line that starts with `## `. It does not know about code fences.
`ledger.md` shows its table inside a fenced example that starts with
`## Open items`. So `section ledger.md "The table"` stopped at that line, and
a check for a row in the Status table below it failed with the right text in
the file.

## The rule

Before a check reads a section, look for a `## ` line inside a code fence in
that section. When there is one, match the line against the whole file. A row
or a sentence that is on one line needs no section.
