# A recursive parser must fail as a parse error

**Learned:** 2026-11-11 · **From:** /build nested-git-commands

`git-command.py` reads each nested `$( )` with one more Python call. A
command with 2000 nested `"$(` levels raised `RecursionError`. The guard
callers catch `ValueError` only. `block-dangerous.sh` blocked the command
because it blocks any exit that is not 0, but a caller that imports the module
would crash. The unit cases nested only 3 or 4 deep, so they never got near
the limit.

## The rule

When a parse function calls itself on its input, turn Python's
`RecursionError` into the exception that the callers already handle. Test it
with input nested deeper than about 1000 levels.
