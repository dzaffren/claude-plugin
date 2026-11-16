# A rule on the program word needs a splitter that knows substitutions

The target guard's new `$` program rule passed its tests, but a replay of
logged commands showed false blocks. The splitter ended a command at the `)`
of `$( )` or `<( )`, so `tail -n +$(grep ...) $G/body.md` read `$G/body.md`
as a program. It also read the words of `$(( ))` and `(( ))` as a command.

**Rule:** before you add a check on the first word of a command, make the
splitter go on with the outer command after `$( )`, `<( )`, `>( )` and
backticks, and drop arithmetic words. Then replay logged commands through the
old and new hook.
