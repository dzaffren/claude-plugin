# A skill edited this session does not take effect this session

**Learned:** 2026-05-04 · **From:** /ship, forge PR #6 (ported 2026-09-11)

Claude Code loads `SKILL.md` and its references when the session starts.
Editing them mid-session does not hot-reload. Invoking the skill afterwards
runs the *old* text, however clean the `git diff` looks on disk.

Watched live on forge PR #6: `/ship` ran its pre-code-review flow even though
the new gate had merged into `SKILL.md`. Wrong: edit a skill, then invoke it to
test the change. Right: start a new session, or execute the new instructions by
hand by reading the file. This is also why a plugin rebuilt on disk this session
is not invocable until the next one.
