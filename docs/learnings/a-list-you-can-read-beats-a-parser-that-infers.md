# A list you can read beats a parser that infers

**Learned:** 2026-09-12 · **From:** ship-naming review

`verify-ship-gates.sh` flags leftover `{placeholder}` text in a spec. It was
firing on things that were not leftovers — mermaid's `{{node}}` syntax, the
gherkin in the acceptance criteria, the convention's own `{type}/{slice}`.

The first fix tried to be clever: blank every fenced block and every inline
code span, then scan what remains. Review found four defects in that one hunk.

| What | Result |
| ---- | ------ |
| An odd number of ```` ``` ```` lines | the flag sticks on, the rest of the spec is blanked, real placeholders pass |
| A backtick used as an apostrophe | pairs with the next real one, deletes a real placeholder between them |
| `TODO` and `[TBD]` inside any fence | stopped being caught at all — a regression |
| A fence indented inside a list item | still flagged — the false positive it was written to remove |

Two regressions against code that was already right, to fix a false positive
that a five-word addition to the existing exclusion list also fixes:

```bash
grep -vE '/s/\{token\}|\{N\}|GET /|POST /|\{\{|\{type\}|\{scope\}|\{subject\}|\{slice\}|\{question\}'
```

## The rule

A documented format and an unfilled blank are the same characters. Nothing can
tell them apart by looking, so do not build something that pretends to. Name
the exceptions in a list. The list is longer to read and impossible to get
subtly wrong.

Reach for the parser only when the exception set is open-ended — when you
cannot enumerate it because you do not control what goes in. Here the workflow
writes the specs, so the set is closed and about nine entries long.

## Where this one came from

The hunk was not in the plan. It was added mid-build to get past a gate
failure. Four of the review's thirteen findings landed in it, and it was the
only unplanned hunk in the diff — worth remembering next time a build wants to
"just quickly fix" something adjacent.
