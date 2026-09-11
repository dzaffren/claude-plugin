#!/usr/bin/env python3
"""Print the git invocations a shell command actually runs.

Reads one shell command on stdin. Prints one line per bare `git` token — its
arguments, unquoted and space-joined, with redirections and git's own options
dropped so the subcommand comes first. A preceding word does not hide it:
`sudo git commit` and `VAR=x git commit` both count. A `git commit` inside a
quoted argument or a heredoc body is text, not a command, so it is not printed.

Exit 0 with or without output. Exit 3 when the command cannot be parsed, which
tells the caller to fall back to matching the raw text and block.
"""
import re
import shlex
import sys

# <<EOF, <<-EOF, <<'EOF', <<"EOF".
HEREDOC = re.compile(r'<<-?[ \t]*(["\']?)(\w+)\1')

# What ends one command. shlex glues a run of punctuation into a single token,
# so `&&\n` and a blank line both arrive as one token — test the characters,
# not the token. Redirections are not here: `git > log commit` is still one
# command, and treating `>` as an end would lose the subcommand.
SEPARATOR_CHARS = set(";&|()`\n")

# `>`, `>>`, `<`, `>&`. A bare `&` is a separator and is tested first.
REDIRECTION_CHARS = set("<>&")

# git's own options, which sit before the subcommand. These take a value.
GLOBAL_OPTIONS_WITH_VALUE = {
    "-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path",
    "--super-prefix",
}


def openers_in(line, quote):
    """Heredoc delimiters opened by this line, and the quote state it ends in.

    `echo '<<EOF'` opens nothing — it is a string. Only an unquoted `<<` does,
    which is why the quote state has to be carried in from the line before.
    """
    delimiters = []
    at = 0
    while at < len(line):
        char = line[at]
        if quote:
            if char == quote:
                quote = None
            elif char == "\\" and quote == '"':
                at += 1
        elif char in "'\"":
            quote = char
        elif char == "\\":
            at += 1
        elif line.startswith("<<<", at):
            at += 2                      # a here-string, not a heredoc
        else:
            match = HEREDOC.match(line, at)
            if match:
                delimiters.append(match.group(2))
                at = match.end() - 1
        at += 1
    return delimiters, quote


def strip_heredocs(command):
    """Drop heredoc bodies. They are raw text; shlex would read them as words."""
    lines = command.split("\n")
    kept = []
    index = 0
    quote = None
    while index < len(lines):
        line = lines[index]
        kept.append(line)
        delimiters, quote = openers_in(line, quote)
        index += 1
        for delimiter in delimiters:
            # Bodies are never scanned for quotes: an apostrophe in prose is
            # an apostrophe, not the start of a string.
            while index < len(lines) and lines[index].strip() != delimiter:
                index += 1
            if index >= len(lines):
                raise ValueError("heredoc %s is never closed" % delimiter)
            index += 1
    if quote:
        raise ValueError("unbalanced %s quote" % quote)
    return "\n".join(kept)


def tokenise(command):
    lex = shlex.shlex(command, posix=True, punctuation_chars="();<>|&`\n")
    lex.whitespace_split = True
    lex.whitespace = " \t\r"
    return list(lex)


def is_separator(token):
    return bool(token) and all(ch in SEPARATOR_CHARS for ch in token)


def is_redirection(token):
    return (bool(token) and all(ch in REDIRECTION_CHARS for ch in token)
            and any(ch in "<>" for ch in token))


def subcommand_args(args):
    """Walk past redirections and git's own options: `> log commit` -> `commit`."""
    rest = list(args)
    while rest:
        head = rest[0]
        if is_redirection(head):
            rest.pop(0)
            if rest:
                rest.pop(0)                       # its target
        elif head.isdigit() and len(rest) > 1 and is_redirection(rest[1]):
            rest.pop(0)                           # the fd in `2>&1`
        elif head.startswith("-"):
            option = rest.pop(0)
            if option in GLOBAL_OPTIONS_WITH_VALUE and rest:
                rest.pop(0)
        else:
            break
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
                found.append(subcommand_args(args))
                args = None
            continue
        if args is not None:
            args.append(token)
        elif token == "git":
            args = []
    if args is not None:
        found.append(subcommand_args(args))
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
