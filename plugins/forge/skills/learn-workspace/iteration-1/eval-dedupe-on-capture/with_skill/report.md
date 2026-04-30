UPDATED: convention-use-vitest
File: .claude/learnings/convention-use-vitest.md
Merged:

- Added new source entry to the `source:` field (now a list): "/learn — 2026-04-28 reminder after PR review flagged a PR still using Jest imports". The original "/learn — initial capture during Q1 migration" entry is preserved.
- Expanded **Why** with a sentence noting the rule is actively enforced in review (reviewer flagged a PR on 2026-04-28 containing Jest imports), so the failure mode is live, not theoretical.
- Expanded **How to apply** with a concrete pre-PR check: grep the diff for `from "jest"`, `from '@jest/globals'`, and `jest.fn(` outside `packages/legacy-billing/`, because reviewers will block the PR otherwise.

Dedupe decision: INDEX.md already contained an entry pointing to `convention-use-vitest.md` ("Use Vitest, not Jest"), and CLAUDE.md's `## Learnings` section already carried the rule. Per the skill's Step 2, this is a near-duplicate (same rule, new wording + new source from an PR review flag), so UPDATE mode was run on the existing file instead of creating a second one.

Files modified: only `.claude/learnings/convention-use-vitest.md`.
INDEX.md: unchanged (no new entry appended — dedupe matched).
CLAUDE.md: unchanged (the existing `## Learnings` bullet already states the Vitest rule; no new nuance needs to surface at the CLAUDE.md level).
