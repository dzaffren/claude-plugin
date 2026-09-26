# A tokeniser's comment handling can swallow the command separator

**Learned:** 2026-09-26 · **From:** /review of owasp-lens (finding H1)

`scope-verifier-bash.sh` split the verifier's command with `lib/git-command.py`'s
shlex tokeniser and checked every command it found. A payload of
`git diff main #`, a newline, then `ls /` exited 0. shlex treated `#` as the start
of a comment that ran to the end of the input, so the newline that separated
the two commands disappeared, and `ls /` never reached the check. `main#x`
followed by a newline did the same. A second finding (H2) had the same shape:
`git diff {--output=/tmp/x,main}` passed because bash brace-expands it into a
refused option the parser never saw as a separate word.

The fix was a first layer that needs no parser: allow-list the raw command's
characters (letters, digits, space, `. _ / : @ ^ ~ = , + -` and plain quotes)
and block anything else by name. The parse stays as a second layer.

## The rule

A guard that allows commands never trusts a tokeniser alone to find every
command. Allow-list the characters of the raw text first, so newlines, `#`,
braces, globs and joiners block before any parser can misread them. Test each
with a payload whose second line is a command the guard must refuse.
