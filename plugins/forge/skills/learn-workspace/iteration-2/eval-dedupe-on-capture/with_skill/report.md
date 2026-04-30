# Learn Skill Eval — Dedupe on Capture (with_skill)

## Outcome

**UPDATED:** `convention-use-vitest`

The skill detected a near-duplicate against the existing `convention-use-vitest.md` entry in `docs/learnings/INDEX.md` and correctly ran UPDATE mode per Step 2 of the `learn` skill, rather than creating a second file.

## Files modified

- `docs/learnings/convention-use-vitest.md` — merged new source and expanded body

## Files NOT modified (as expected)

- `docs/learnings/INDEX.md` — no new entry; existing pointer still correct (5 lines)
- `CLAUDE.md` — existing `## Learnings` rule for "Use Vitest, not Jest" already present; no edit needed (24 lines)

## What was merged

- **source** expanded from a single string into a list, preserving the original Q1 migration capture and appending the new entry: `/learn — 2026-04-28 reviewer flagged a PR that still had Jest imports`.
- **Why** extended with a sentence noting reviewers actively catch stray Jest imports in PR review (observed 2026-04-28), explaining why the rule still actively matters.
- **How to apply** extended with a concrete pre-PR check: grep for `from "jest"` / `from '@jest/globals'` in changed test files before opening an PR.

The rule itself (first line) was left unchanged — the new observation reinforces the existing rule rather than refining it.

## Write status

All writes succeeded. Only one file was touched (`convention-use-vitest.md`), matching the expected behavior for dedupe-on-capture.

## Summary

- Files modified: `docs/learnings/convention-use-vitest.md` (only)
- INDEX.md grew? No (still one entry, 5 lines)
- CLAUDE.md grew? No (still 24 lines)
- Writes succeeded? Yes
