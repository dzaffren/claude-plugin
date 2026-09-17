# An acceptance test needs an acceptable fixture

Session C of the study e2e asserted that a reasoned decision is not marked
wrong. The skill's `Decide:` block asked the user to cover collisions,
guessability and two API servers. The fixture answered on collisions, and the
test asserted the reply must not open `Not yet.`

So the assertion said: a one-of-three answer must be waved through. It passed
for a year of runs — until the skill got better at spotting incomplete
reasoning, and then the improvement read as a regression.

A test that asserts "the agent should accept X" is only meaningful when X is
genuinely acceptable. Otherwise it pins the agent's leniency in place and goes
red the moment the agent improves. The same holds inverted: a test asserting
rejection needs a fixture that genuinely deserves rejecting, or it passes on
the agent being harsh.

Write the fixture to the standard the prompt actually sets. If the prompt asks
for three things, the fixture answers three things.

Related: [[read-the-transcript-before-editing-the-prompt]] — the transcript is
what told us the skill was right and the fixture was wrong. Without it this
would have become another round of loosening the skill.
