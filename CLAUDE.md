# CLAUDE.md

Guidance for Claude Code when working on this repo (the forge plugin).

## Learnings

- **Skill step numbering vs. data deps** — In any skill with numbered steps, confirm the producer step runs before every consumer and that the producer's contract explicitly records the value it returns. See `docs/learnings/blocker-skill-step-numbering-vs-data-deps.md`.
- **git checkout destroys uncommitted work** — Never use `git checkout -- <files>` (or `git restore <files>`) to revert an auto-applied patch when the working tree has other uncommitted changes. Use `git apply -R <patch>` instead. See `docs/learnings/blocker-git-checkout-destroys-uncommitted-work.md`.
- **code-reviewer gate before commit** — Keep `/ship` Step 0.5 as a blocking gate; walk through FAIL findings individually rather than bulk-accepting. See `docs/learnings/win-code-reviewer-gate-before-commit.md`.
