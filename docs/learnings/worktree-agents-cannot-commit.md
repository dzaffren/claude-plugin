# Check that a worktree agent actually committed

**Learned:** 2026-05-04 · **From:** /build, forge PR #6 (ported 2026-09-11)

Agents launched with `isolation: worktree` can be denied git write commands.
They edit files fine and then return without landing a commit. It is not
uniform — in one run three sub-tasks committed and the fourth was denied, so
the denial tracks the session's permission history, not the agent.

Wrong: assume the branch has the work because the agent said it finished.
Right: read each agent's report for commit evidence, and when one is missing,
`cd` into its worktree, `git status --short`, and commit there yourself using
the message the agent proposed.
