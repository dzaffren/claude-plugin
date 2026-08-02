---
name: ship
description: >
  Final gate before the work leaves the machine. Use after /quality and
  /security pass, or when the user says "ship it", "prepare the PR", "ready
  to merge". Verifies every gate, tidies the branch, updates docs, and
  prepares — but never pushes — the merge request.
---

# Ship

Everything green, branch tidy, docs true, ready to hand over. Pushing and
opening the PR/MR stay the user's move.

## Steps

1. **Check the gates.** Confirm, by looking not by memory:
   - Spec status is `Built` and every acceptance scenario has a passing test
     (rerun the full test command now; show the output).
   - /quality ran; flagged items are fixed or explicitly accepted by the user.
   - /security ran; no unresolved Critical/High findings, no secrets in the
     branch history.
   If a gate fails, stop and report which one — don't ship around it.

2. **Tidy the branch.** `git status` clean, no untracked files that should be
   ignored. Commits in logical chunks with messages matching the repo's style.
   Never rewrite history that predates this branch.

3. **Sync the docs.** If behavior, commands, or config changed: update
   README/CHANGELOG/CLAUDE.md as the repo's convention dictates. Update the
   spec's Status to `Shipped`, regenerate its HTML (spec-html skill), and
   refresh the index (`md2html.py --index docs/specs`).

4. **Write the handover.** A short merge-request description: what changed
   and why (link the spec), how it was tested (real results), anything the
   reviewer should look at first. Save it in the final commit message body or
   paste it in the reply — whichever the repo's flow uses.

5. **Capture lessons automatically** (learn skill). Last chance before the
   session's signals are gone: user corrections across the whole run,
   blockers, review themes. Write them to `docs/learnings/` without asking
   and include them in the final commit.

6. **Stop before the push.** Report: gates passed, branch name, commit list
   (`git log --oneline main..HEAD`), the handover text, and the spec's
   `file://` link. Ask before pushing or opening the PR/MR — never do either
  unprompted.
