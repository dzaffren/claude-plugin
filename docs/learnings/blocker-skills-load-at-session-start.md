---
name: skills-load-at-session-start
description: Claude Code loads skill contents at session start; mid-session edits to a skill do not take effect until the next session
type: blocker
captured: 2026-05-04
source: /ship — ship-release-automation feature (PR #6)
---

Claude Code's `Skill` tool loads skill files (`SKILL.md`, supporting
references) when the session starts. Edits to those files during the
current session do NOT hot-reload. When you invoke `/forge:ship` or
`/forge:learn` later in the same session, you run the **old** version
of the skill, even if your `git diff` shows the new prose clearly
merged on disk.

**Why:** The skill-loading mechanism caches content at the point the
tool is first presented. This keeps tool definitions stable across a
conversation. But it means you cannot iterate on a skill and test it
in the same session — you either:

1. Run the old skill content (useful for testing that the NEW version
   matches or beats the OLD), OR
2. Start a new session (slash commands in the new session see the
   updated disk state), OR
3. Execute the new skill content manually in the chat by having the
   assistant re-read the file and follow the updated instructions.

Watched this live during the ship of PR #6: `/forge:ship` ran with the
pre-code-review Step 0 → Step 1 → ... flow, despite PR #3 having merged
the Step 0.5 code review gate and Step 8 changelog sync into `SKILL.md`
on disk. The parent session had to run security-review and
code-reviewer manually to honor the new contract.

**How to apply:** When iterating on a forge skill:

1. **After editing a SKILL.md, the changes take effect next session —
   not this one.** If you need to test the new version in the current
   session, execute it manually by reading the file and following the
   instructions yourself.
2. **For in-session skill edits that affect `/ship`, `/fix`,
   `/security-review`, or any gating skill**, explicitly add a note to
   the ship/build workflow: "Note: the loaded /ship skill is the PRE-
   <feature> version; the new gates will fire next session."
3. **For the first `/forge:ship` AFTER a session where a ship skill
   changed**, eyeball the flow: if the skill's text mentions new steps
   the assistant seems to be skipping, start a new session so the
   updated skill loads fresh.
4. **Never assume a post-edit skill invocation in the same session
   tests the updated skill.** It tests the pre-edit one.

**What was tried:** Completed PR #3 (new Step 0.5 + Step 8) → cut PR #4
(release) → captured learnings (PR #5) → all in one session. When PR
#5 merged and we started the ship-release-automation build, `/forge:ship`
STILL ran the pre-PR-3 flow. Workaround: manually invoked
`security-review` and the `code-reviewer` agent in the parent session
to honor the new contract, then proceeded. The workaround adds ~2
minutes per ship but is reliable.
