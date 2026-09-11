#!/usr/bin/env python3
"""Print the git invocations a shell command actually runs.

Reads one shell command on stdin. Prints one line per `git` found at a command
position: the arguments after it, unquoted and space-joined. A `git commit`
inside a quoted argument or a heredoc body is text, not a command, so it is not
printed.

Exit 0 with or without output. Exit 3 when the command cannot be parsed, which
tells the caller to fall back to matching the raw text and block.
"""
import re
import shlex
import sys

# <<EOF, <<-EOF, <<'EOF', <<"EOF". `<<<` is a here-string, a single argument,
# so it never opens a body — the leading `<` stops \w+ from matching.
HEREDOC = re.compile(r'<<-?[ \t]*(["\']?)(\w+)\1')

# Where a command word can start. `(` and ` for subshells, `\n` because a
# newline ends a command as surely as `;` does.
SEPARATORS = {";", "&&", "||", "|", "&", "(", ")", "`", "\n"}


def strip_heredocs(command):
    """Drop heredoc bodies. They are raw text; shlex would read them as words."""
    kept = []
    pending = []
    for line in command.split("\n"):
        if pending:
            if line.strip() == pending[0]:
                pending.pop(0)
            continue
        kept.append(line)
        pending = [m.group(2) for m in HEREDOC.finditer(line)]
    if pending:
        raise ValueError("heredoc %s is never closed" % pending[0])
    return "\n".join(kept)


def tokenise(command):
    lex = shlex.shlex(command, posix=True, punctuation_chars="();<>|&`\n")
    lex.whitespace_split = True
    lex.whitespace = " \t\r"
    return list(lex)


def invocations(tokens):
    """The argument list of every `git` standing at a command position."""
    found = []
    at_command = True
    args = None
    for token in tokens:
        if token in SEPARATORS:
            if args is not None:
                found.append(args)
                args = None
            at_command = True
            continue
        if args is not None:
            args.append(token)
        elif at_command and token == "git":
            args = []
        at_command = False
    if args is not None:
        found.append(args)
    return found


def main():
    command = sys.stdin.read()
    try:
        tokens = tokenise(strip_heredocs(command))
    except ValueError as err:
        sys.stderr.write("git-command.py: cannot parse the command: %s\n" % err)
        return 3
    for args in invocations(tokens):
        print(" ".join(args))
    return 0


if __name__ == "__main__":
    sys.exit(main())
