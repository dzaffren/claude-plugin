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

# What ends one command. shlex glues a run of punctuation into a single token,
# so `&&\n` and a blank line both arrive as one token — test the characters,
# not the token.
SEPARATOR_CHARS = set(";&|()`<>\n")

# git's own options, which sit before the subcommand. These take a value.
GLOBAL_OPTIONS_WITH_VALUE = {
    "-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path",
    "--super-prefix",
}


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


def is_separator(token):
    return bool(token) and all(ch in SEPARATOR_CHARS for ch in token)


def strip_global_options(args):
    """Drop git's own options so the subcommand is first: -C x commit -> commit."""
    rest = list(args)
    while rest and rest[0].startswith("-"):
        option = rest.pop(0)
        if option in GLOBAL_OPTIONS_WITH_VALUE and rest:
            rest.pop(0)
    return rest


def invocations(tokens):
    """The arguments of every bare `git` token.

    Bare is the whole test. Quoting collapses "how to git commit" into one
    token, and heredoc bodies are gone by now, so prose can never produce a
    `git` token on its own. Everything else is treated as a real invocation —
    `sudo git`, `VAR=x git`, `do git` inside a loop — because a guard that
    tries to list the wrappers it knows about will always miss one.
    """
    found = []
    args = None
    for token in tokens:
        if is_separator(token):
            if args is not None:
                found.append(strip_global_options(args))
                args = None
            continue
        if args is not None:
            args.append(token)
        elif token == "git":
            args = []
    if args is not None:
        found.append(strip_global_options(args))
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
