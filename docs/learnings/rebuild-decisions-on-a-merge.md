# Rebuild DECISIONS.md on a merge, never take git's hunks

**Learned:** 2026-10-05 · **From:** /ship design-system, ascii-terminal, jira-shape

Three slices built in parallel each appended one entry to `DECISIONS.md`.
Merging main into the second branch, git aligned both new entries on their
shared last line, `Status: active`, and the "keep both sides" resolution
left D22 with no Status line. `decisions.py check` catches a missing line,
but only if it is run.

## The rule

Resolve a `DECISIONS.md` conflict by rebuilding it: the base branch's file,
then this branch's new entries appended whole
(`git show origin/main:DECISIONS.md`, then the entries from `HEAD`). Then
run `decisions.py check . --base origin/main` before committing the merge.
