# Find a section by its whole heading line, not by its words

**Learned:** 2026-10-13 · **From:** decision-pr spec

A script split the drafted decisions in `docs/specs/decision-pr.md` with
`s.index("## Open items")` as the end of the section. The spec's Interface
said "`/review` writes it just above `## Open items`", so the inline mention
matched first. The end came before the start, and
`s[:start] + new + s[end:]` wrote 258 lines twice. The refine commit and the
decisions commit both carried the copy, and a later edit failed only because
its old text now matched twice.

## The rule

Find a heading as a whole line: `"\n## Open items\n"`. Assert `end > start`
before a slice, and assert that each old text matches once. zuko specs
quote their own headings in backticks all the time, so the bare words are
never unique.

## The same class, in a parser

`/review` found it again in `pr_body.py`'s `sections()`. It skipped a heading
inside a fence but still added the fenced lines to the section above, so a
fenced example row under `## Open items` was read as a real row. A section
parser drops every line inside a fence, and the fence lines too, not only the
headings. Test it with a fence directly under the real heading, not under an
`## Interface` that no check reads.
