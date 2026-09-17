# A negative example still hands over the answer

The study skill must give a hint without naming the thing the user has to work
out. To make that concrete it carried a table:

| Their attempt | A hint | Not a hint |
| ------------- | ------ | ---------- |
| `except FileNotFound:` | "look up what `open()` raises" | the right name, spelled out |

The example was written from the e2e's own fixture, so at the exact moment the
rule had to hold, the skill was showing the model the answer string. The run
leaked it.

A "do not write X" example that contains X is a loaded gun. Write the worked
example from a different case than the one the rule will be tested on, and
state the rule in a form that needs no forbidden string: "when the error is a
wrong name, never write the right name."

This is the inverse of [[match-the-artifact-not-its-description]]. A guard's
pattern should be copied from the real artifact; a prompt's example should be
kept away from the real case.
