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

## Again in release-commit.py (2026-10-07, pentest v2.3.0 P1)

`whole_call` refused `$`, backticks and `();<>|&`, but not braces or globs, so
`-m {body,--all}` reached git as `-m body --all` on main. A raw allow-list did
not fit: the release body is free text that names `[2.3.0]` inside quotes. The
fix made `{}[]*?` shlex punctuation, which splits them out only when unquoted.
When the text must carry these characters, refuse them outside quotes.

## Again in git-command.py (2026-10-13, fail-closed-parse)

The main-thread guards cannot refuse `#`, so the parser took bash's rule:
a comment starts at an unquoted `#` at the start of a word, and opens no
quote or heredoc. shlex had started one at any `#`, so `echo x#;` hid the
command after it. One rule needed care: after `$(date)`, bash keeps `#` in the
word, and after a subshell's `)` it starts a comment. The first build said
"read too little as a comment, never too much". /review proved that false:
read as text, `(true)# <<EOF` opened a heredoc that hid the next line. And
after `${`, `$'`, a backtick or a `$(` in double quotes, the parser's quotes
are not bash's, so a `#` it read as a comment hid `; git push --force`.

Neither reading of an unclear `#` is safe on its own. Read it as text, and
refuse the command when that text holds a quote, a backtick, `<<` or a line
continuation: the things that change what the walk reads next.

## Again for `<<` (2026-10-13, pentest v2.4.1)

The walk read every unquoted `<<` as a heredoc. Inside `(( ))`, `$(( ))`,
`$[ ]` and `${ }`, bash reads it as a shift, so `(( 1 << X ))` hid a force
push on the next line. Skipping those brackets was no fix: bash reads
`((cat << X); (true))` as two subshells and a heredoc. The walk now refuses a
`<<` inside them. When bash reads a symbol in two ways, test each place bash
can meet it, not only the place you had in mind.
