# A finding-verifier has no Bash, so it guesses at library behaviour

**Learned:** 2026-09-12 · **From:** /review hook-command-match

`zuko:finding-verifier` is defined with `Read, Grep, Glob` — no `Bash`. On a
finding that turned on how Python's `shlex` tokenises a run of punctuation,
two of three verifiers rejected it, both stating that `&&` arrives as two `&`
tokens. It arrives as one. Five seconds of `python3 -c` settles it; neither
could run those five seconds, so the 2-of-3 vote killed a real false-allow in
a security guard.

## The rule

The verifier vote is a filter against speculation, not an oracle over facts.
When a finding rests on observable behaviour — a library's output, an exit
code, a regex match — run it yourself before accepting the vote either way,
and say in the report that you overrode it and on what evidence.

Better: have the reviewer, which does have `Bash`, paste the actual observed
output into the claim it hands over. A verifier reading `tokens are ['a',
'&&', 'git']` recorded from a real run is judging evidence rather than
recalling documentation.

Rejections that need no rerun are the ones the vote is good at: unreachable
paths, pre-existing behaviour, style dressed up as a bug.
