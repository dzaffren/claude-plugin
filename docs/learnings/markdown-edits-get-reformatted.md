# Markdown edits get reformatted behind your back

**Learned:** 2026-10-05 · **From:** /build design-system, jira-shape, ascii-terminal

Three chunk-builders each found a PostToolUse formatter rewriting the whole
Markdown file after an Edit or Write: every table realigned, `*x*` turned
into `_x_`, blank lines added under headings. It is not zuko's
`auto-format.sh` — that runs prettier only from the repo's own
`node_modules`, and this repo has none — so it comes from a hook installed
outside the repo.

## The rule

After editing a Markdown file, read `git diff` and restore every line you
did not mean to change, or apply the text change with a short script, which
the hook does not see. A moved block of prose has to diff as a move, and a
one-line fix must not ship as a 50-line table realignment.
