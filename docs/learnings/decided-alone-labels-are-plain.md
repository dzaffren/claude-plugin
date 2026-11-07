# Write a Decided alone row's labels as plain text

**Rule:** In a `Decided alone` row, write `Chose:`, `Other:` and `Undo:` as
plain text, never in bold.

**Why:** `pr_body.py` splits the Answer cell on the bare labels. A bold label,
`**Chose:**`, leaves its `**` in the cell before and after the split, so each
column of the PR's Your call table starts and ends with stray `**`. The ship
gate still passes, because it finds the labels inside the bold. Seen in
`lf-checkout` at /ship (2026-11-07), and `unattended-build` has the same rows.

**How to apply:** Copy the row shape from `references/ledger.md`. Before the
PR, read the rendered body from `pr_body.py render` and look for `**`.
