# Render a new output from the repo's own spec before it ships

**Learned:** 2026-10-13 · **From:** decision-pr ship

`pr_body.py` passed 47 unit cases, a 17-case e2e and a three-verifier review.
Its first run on a real spec, this slice's own PR body, split row O15 inside
the quoted text `has an empty "Undo:"`. Every fixture had plain Answers; the
real rows, written by `/review` about the parser itself, quoted the labels
the parser splits on. The gate passed, because each label was somewhere in
the cell.

## The rule

When a slice adds a parser or a renderer over zuko docs, run it on the real
docs in the repo before the PR, and read the output, not only the exit code.
Fixtures hold the text you thought of. The repo's own specs hold the text
that people and stages actually write.
