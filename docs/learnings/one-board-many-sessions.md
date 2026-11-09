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

A refusal marks the live version as seen. The next publish then goes through
with no warning, and it replaces the other session's card. That happened at
`/review exe-lookup`, and the other session's version had to be published
again from the saved copy. So while another session is at a stop on the same
idea, serve locally for each later publish too, and do not try the publish.
