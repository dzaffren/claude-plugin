# In a numbered skill, the step that produces data must be numbered below the one that reads it

**Learned:** 2026-05-04 · **From:** /ship code-review gate, forge PR #3 (ported 2026-09-11)

Steps run in numeric order, not in the order they read on the page. A consumer
placed above its producer sees empty state and skips silently — no error, no
output, nothing to notice. Caught twice in one session on the same skill.

Wrong: numbering a sync step 6.5 because it sits next to step 7 in the text and
"will read step 7's output". Right: renumber it after its producer, and make the
producer state the contract out loud ("record X; step 8 consumes it"). Sync-type
steps — append to a log, update an index, post a report — belong last.
