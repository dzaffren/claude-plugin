# A stricter twin of a pattern belongs on every path that uses the original

**Learned:** 2026-11-10 · **From:** /debug of the v2.7.0 pentest S1

`e8211f3` found that `HEREDOC`'s `(\w+)` reads only a prefix of a heredoc
delimiter: in `<<EOF-1`, bash's delimiter is `EOF-1`. It added
`INNER_HEREDOC`, which also needs the delimiter to end at a shell
metacharacter, and used it inside a double-quoted `$( )`. The top-level walk
kept `HEREDOC`. Four weeks later Strix hid `git push --force` after
`cat <<E-F`: the walk took `E` as the delimiter and dropped the push as body.

## The rule

When a fix adds a stricter copy of a regex or a check for one call site,
grep for every other use of the original before you commit. Fix each one, or
say in the commit why that one is safe. A comment that names the bug (here,
"`<<EOF-1` is `EOF-1`, not `EOF`") is a sign that the bug exists everywhere
the old pattern still runs.
