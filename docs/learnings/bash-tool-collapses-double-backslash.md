# The Bash tool turns a double backslash into one

**Learned:** 2026-11-08 · **From:** /build utf8-stdio

A Python edit sent through the Bash tool held `newline="\\n"` inside a quoted
heredoc, so that the file would get `newline="\n"`. The file got a real line
break inside the string instead, and `release-commit.py` stopped with a
`SyntaxError`. `grep 'newline="\\n"'` also found nothing in files that held
the text. The command reached bash with each `\\` already turned into `\`, so
the quoted heredoc did not protect it.

## The rule

Write code that holds a backslash with the Write tool, as a file. Then run
that file. In a Bash command, build a backslash with `chr(92)`, or search with
`grep -F` for text that has none. After an edit through the shell, parse each
changed file: `ast.parse` for Python, `bash -n` for a script.
