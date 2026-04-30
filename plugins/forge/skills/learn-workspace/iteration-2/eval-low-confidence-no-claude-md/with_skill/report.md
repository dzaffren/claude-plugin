# Learn skill eval — low-confidence, no-CLAUDE.md report

## Outcome

CAPTURED: pattern-auth-test-seeding
File: docs/learnings/pattern-auth-test-seeding.md
Index updated: yes (INDEX.md created — this was the first learning in the repo)
CLAUDE.md updated: no — low-confidence signal

## Files created

- `repo/docs/learnings/INDEX.md` — new index file with header and one pointer entry
- `repo/docs/learnings/pattern-auth-test-seeding.md` — the learning file

## CLAUDE.md was NOT touched

Confirmed. The fixture `CLAUDE.md` mtime (`2026-04-28 13:20:52`) is unchanged after the run; only `docs/learnings/` files were created.

## Why CLAUDE.md was not updated

Per Step 5 of the skill, `CLAUDE.md` only gets a `## Learnings` entry when the observation is high-confidence. High-confidence requires ONE of:

- Absolute language ("always", "never", "from now on", "we don't", "we do")
- Explicit user request to update CLAUDE.md
- A `learning-capturer` agent proposal the user explicitly approved as a rule

The user's phrasing — "tend to use", "not a hard rule", "just something I've noticed" — is the textbook low-confidence signal. It is an observed tendency, not a team-endorsed rule, so it stays in `docs/learnings/` only where it is preserved for future reference without being injected into every session's base context.

## Type choice

`pattern` — the observation names a specific reusable building block (the `seedUserWithRole` fixture used in auth tests). Per `references/types.md`, this matches the canonical example for the pattern type almost verbatim. It is not a style convention, not a dead-end blocker, and not a skill-behavior correction.

## Writes succeeded

Both files exist on disk with expected sizes (INDEX.md 345 bytes, pattern-auth-test-seeding.md 1146 bytes). Directory `repo/docs/learnings/` was created as part of the write.
