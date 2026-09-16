# Read the transcript before editing the prompt

Six live runs of the study e2e produced six failures after the skill existed.
One was the skill. Five were the test measuring the wrong thing:

- it read only the `result` event, which carries the final assistant message
  alone, so a line printed before a stretch of tool calls was invisible
- it read the turn's first text as the verdict, but a turn that runs the user's
  code opens with a preamble above the tool call
- it demanded a word the quoted traceback has to contain, because Python chains
  the original exception under a `NameError`
- twice, a `grep` that never ran ([[a-check-that-could-not-run-is-not-a-miss]])

Each time the obvious move was to make the skill's rule louder. Each time that
would have made the skill worse and left the real bug in place. Three rounds of
"say it more firmly" is the tell that the rule is not what is broken.

So: when a prompt-driven test fails, print what the run actually produced
before touching the prompt. Keep the transcripts on failure — reproducing one
costs real money — and number them per turn, or the failing turn is overwritten
by the one after it.

Related: [[match-the-artifact-not-its-description]], for the other half of the
same habit — write the check from the artifact, not from the prose about it.
