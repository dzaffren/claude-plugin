# Lessons

One line per lesson. Loaded into every session in this repo.

- A gate that scanned nothing must never exit 0 — report scope on every
  outcome, error on an absent target, and test the empty case.
  ([detail](gate-scanned-nothing-is-not-a-pass.md))
- A skill edited this session does not take effect this session — start a new
  session, or execute the new instructions by hand.
  ([detail](skills-load-at-session-start.md))
- Check that a worktree agent actually committed — the denial is not uniform,
  and a silent one loses the chunk.
  ([detail](worktree-agents-cannot-commit.md))
- Reverse a patch with `git apply -R`, never with checkout — checkout discards
  the user's uncommitted work too.
  ([detail](never-checkout-to-undo-a-patch.md))
- Pick `${CLAUDE_PLUGIN_ROOT}` or `${CLAUDE_SKILL_DIR}` by where the file lives,
  not by the surrounding style.
  ([detail](plugin-root-vs-skill-dir.md))
- In a numbered skill, the producing step must be numbered below the one that
  reads it — otherwise it skips silently.
  ([detail](producer-steps-run-before-consumers.md))
- When parallel chunks would share a file, re-cut them by file — disjoint
  ownership is what keeps the merges clean.
  ([detail](chunk-by-file-not-by-story.md))
- A guard whose verdict depends on the current branch or staged diff must be
  tested against a scratch repo in that state, not the session's.
  ([detail](test-the-guard-where-it-fires.md))
- Swapping a broad matcher for a precise one turns false blocks into false
  allows — diff old against new on the same inputs before shipping.
  ([detail](tightening-a-matcher-trades-blocks-for-allows.md))
- A finding-verifier has no Bash — when a finding turns on real library
  behaviour, run it yourself instead of trusting the vote.
  ([detail](verifiers-cannot-run-code.md))
- The test harness is the first chunk, never the last — a fixture written
  after the code it covers never failed for the right reason.
  ([detail](harness-before-the-chunks-it-proves.md))
- A guard misbehaving like an older version of itself is the installed plugin
  cache, not the repo — diff the two before debugging the source.
  ([detail](installed-plugin-lags-the-repo.md))
