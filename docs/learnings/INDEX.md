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
- Write a guard's pattern from the artifact it must catch, pasted verbatim —
  not from the spec's prose description of it.
  ([detail](match-the-artifact-not-its-description.md))
- When the exception set is closed, name it in a list — a parser that infers
  which braces are real trades false positives for silent false negatives.
  ([detail](a-list-you-can-read-beats-a-parser-that-infers.md))
- `rebase -i` does not work here — reword a commit by replaying the branch onto
  its base with cherry-pick, and diff against a backup to prove only the
  message moved.
  ([detail](reword-a-commit-without-rebase-i.md))
- Run the whole suite before building on it — a red baseline is its own
  light-path fix first, and exit 127 in a test means a missing command.
  ([detail](run-the-suite-before-you-build.md))
- A worktree agent starts from `main`, not your feature branch — a dependent
  chunk's prompt names the commit it needs and tells it to fast-forward first.
  ([detail](worktree-agents-start-from-main.md))
- A gate's passing branch matches the one allowed value; the catch-all fails
  and names what it saw — denylisting bad values fails open.
  ([detail](gates-allow-the-pass-not-block-the-fail.md))
- A new gate check breaks every fixture that lacks what it checks — commit
  the fixture update before the gate so each commit stays green.
  ([detail](a-new-gate-check-breaks-every-fixture.md))
- A run-once step that gains an artifact a gate requires needs a backfill path
  in a recurring stage, or repos onboarded earlier can never pass.
  ([detail](run-once-steps-need-a-backfill-path.md))
- Integrate a chunk's worktree branch by cherry-pick — a merge commit's
  subject fails the ship gate's naming check.
  ([detail](integrate-chunks-without-merge-commits.md))
- Make a test's temp dir inside run.sh's `$work` — its trap cleans up, and an
  `rm -rf` line in a heredoc trips the org's destructive-command hook.
  ([detail](test-temp-dirs-live-under-run-sh.md))
- A fixture writes every project file before it renders the README —
  the block links to files that exist, so a file added after goes stale.
  ([detail](fixture-files-before-the-render.md))
- A test's `url.<bare>.insteadOf` names the whole remote URL — git takes the
  longest match, and this machine's global config rewrites github.com.
  ([detail](insteadof-longest-match-wins.md))
- A guard over a CLI reads every spelling that CLI's parser accepts —
  aliases, abbreviated long options, `-F=path` — and git and gh differ.
  ([detail](guard-every-spelling-the-parser-accepts.md))
- An agent's `tools:` pattern like `Bash(git diff *)` grants the whole tool —
  scope it with a PreToolUse hook on `agent_type`, and probe it headless.
  ([detail](agent-tools-patterns-are-not-enforced.md))
- A skill's `allowed-tools` must cover every command its subagents run, or
  `-p` refuses them; a guard that blocks an agent says what to use instead.
  ([detail](skill-allowed-tools-cover-its-subagents.md))
- A check that depends on something the diff removes says to read the removed
  (`-`) lines, or the reviewer calls the function unchanged.
  ([detail](reviewers-skim-deleted-lines.md))
- A command guard allow-lists the raw text's characters before tokenising —
  a `#` comment can swallow the newline between two commands.
  ([detail](comments-can-swallow-the-separator.md))
- Never pipe into `grep -q` under `pipefail` — an early match SIGPIPEs the
  writer on text over 64 KB and the pipeline reads as a miss; use a here-string.
  ([detail](grep-q-under-pipefail.md))
