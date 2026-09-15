# Hand a prompt rule cold to fresh agents to find out if it is followable

**Learned:** 2026-09-15 · **From:** /poc on `readable-review-findings` O1

"Will a written rule actually be followed?" sounds unspikeable, because the
honest test is a long real session. It splits into two questions, and one of
them is cheap:

1. **Is the text followable from a cold read?** Give N fresh agents nothing but
   the rule and one realistic input. Count the conforming outputs.
2. **Does it survive forty turns of other work?** No spike settles this. That is
   what a Stop-hook gate is for.

Three agents, given only `references/report.md` and two findings, each wrote a
conforming report — same structure, no severity labels, glossaries differing
only in which words they picked. 3 of 3 means the wording is not the risk, so
the plan stopped trying to fix the wording and left drift to slice 4's gate.

A failure here would have been worth more: agents that drift five seconds after
reading a rule mean the rule is wrong, and no hook rescues it.

The grader written for the spike is also evidence. Mine flagged "csv" inside the
branch name `feat/csv-export`, which is exactly the false positive the shipped
checker had to avoid — a throwaway grader finds the real checker's bugs before
the real checker exists.
