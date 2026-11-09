# One idea board, many sessions

**Learned:** 2026-11-09 · **From:** /build exe-lookup

Each slice of an idea publishes the same board URL. While `/spec exe-lookup`
and `/build exe-lookup` ran, another session ran `/spec windows-ci` on the
same idea, in its own worktree. The publish was refused twice, because that
session had published a newer version with its own gate card. Each render
reads only its own branch, so a publish from one session drops the other
session's gate card and its slice's latest state.

## The rule

When the board publish is refused for a newer version, read which stage
published it. When it is another slice's stop, do not publish over it.
Serve the board on localhost, as the failed-publish path in `visual-page.md`
says, and name the other stage in the `Board not published:` line.
