#!/usr/bin/env python3
"""Print the git invocations a shell command actually runs.

Reads one shell command on stdin. Prints one line per bare `git` token — its
arguments, unquoted and space-joined, with redirections and git's own options
dropped so the subcommand comes first. A preceding word does not hide it:
`sudo git commit` and `VAR=x git commit` both count. A `git commit` inside a
quoted argument, a heredoc body or a comment is text, not a command, so it is
not printed. A comment follows bash's rule: it starts at an unquoted `#` at the
start of a word, so the `#` in `x#` or `${#name}` is part of the word.

With `--dir <base>`, each line is prefixed with the directory that invocation
runs in and a tab: `<base>` moved by a `cd` or `pushd` earlier in a plain `&&`
chain, then by git's own `-C`. The prefix is empty when the text cannot say
where git runs, and the caller must then judge every directory it could be.

Exit 0 with or without output. Exit 3 when the command cannot be parsed, with
the reason on stderr. bash still runs the lines before an unclosed quote, and an
unclosed heredoc to the end of the text, so the caller must block it (D52).
Exit 4 when it is over the length limit.
"""
import os
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

# A backslash at end of line. The shell deletes the pair outright before it ever
# sees a command, so this is not a separator. Left in, a wrapped invocation
# parses as a bare subcommand and every flag after the break is lost.
#
# Deleted, never replaced with a space: the break can fall inside a word, and
# `git pu\<newline>sh --force` runs as `git push --force`. A space would split
# it into `pu` and `sh` and the force-push guard would never see a `push`.
CONTINUATION = re.compile(r"\\\n")

# shlex grows a word one character at a time, so its parse time is quadratic:
# a 1.1 MB command took a guard 20 s, and a hook that times out lets the call
# through. Over this length tokenise refuses at once, and every caller takes
# its own cannot-parse path (D51). Heredoc bodies are gone before it counts.
# main() gives it its own exit code, so block-dangerous.sh can say what to change.
MAX_COMMAND_CHARS = 65536


class TooLong(ValueError):
    pass

# Where bash starts a new word, so that a `#` after one starts a comment. Not
# `)`: after `$(date)` bash keeps `#x` in the word, after a subshell's `)` it
# starts a comment, and reading too little as a comment is the safe side.
WORD_BREAKS = set(" \t;&|(<>")

# git's own options, which sit before the subcommand. These take a value.
GLOBAL_OPTIONS_WITH_VALUE = {
    "-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path",
    "--super-prefix",
}


def openers_in(line, quote, word_start=True):
    """Heredoc delimiters opened by this line, where its comment starts (None
    for no comment), the quote state it ends in, and whether the next line
    starts a word.

    `echo '<<EOF'` opens nothing — it is a string. Only an unquoted `<<` does,
    which is why the quote state has to be carried in from the line before.
    A comment opens nothing either: `# it's` is no quote, `# <<EOF` no heredoc.

    A backslash that ends the line joins the next line to this word, as bash
    deletes the pair, so the next line starts a word only where the backslash
    stood at one: after `echo a\\`, a `#` on the next line is inside `a#`.
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
            word_start = False
        elif char in "'\"":
            quote = char
            word_start = False
        elif char == "\\":
            if at == len(line) - 1:
                return delimiters, None, quote, word_start
            at += 1
            word_start = False
        elif char == "#" and word_start:
            return delimiters, at, quote, True
        elif line.startswith("<<<", at):
            at += 2                      # a here-string, not a heredoc
            word_start = True
        else:
            match = HEREDOC.match(line, at)
            if match:
                delimiters.append(match.group(2))
                at = match.end() - 1
                word_start = False
            else:
                word_start = char in WORD_BREAKS
        at += 1
    return delimiters, None, quote, True


def strip_heredocs(command):
    """Drop heredoc bodies and comments. They are raw text; shlex would read
    them as words."""
    lines = command.split("\n")
    kept = []
    index = 0
    quote = None
    word_start = True
    while index < len(lines):
        line = lines[index]
        delimiters, comment, quote, word_start = openers_in(line, quote, word_start)
        kept.append(line if comment is None else line[:comment])
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
    command = CONTINUATION.sub("", command)
    if len(command) > MAX_COMMAND_CHARS:
        raise TooLong("the command is over %d characters" % MAX_COMMAND_CHARS)
    lex = shlex.shlex(command, posix=True, punctuation_chars="();<>|&`\n")
    lex.whitespace_split = True
    lex.whitespace = " \t\r"
    lex.commenters = ""                  # strip_heredocs drops comments, as bash reads them
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


def resolve(current, path):
    """`current` moved to `path`, or None when the text cannot say where.

    An absolute path needs no `current`: `git -C /repo` is known even after a
    move the walk lost track of.
    """
    if not path or any(ch in path for ch in "$`"):
        return None
    path = os.path.expanduser(path)
    if not os.path.isabs(path):
        if current is None:
            return None
        path = os.path.join(current, path)
    moved = os.path.normpath(path)
    return moved if os.path.isdir(moved) else None


def git_dir(args, current):
    """Where git runs once its own options before the subcommand are applied."""
    rest = list(args)
    while rest and rest[0].startswith("-"):
        option = rest.pop(0)
        if option.startswith(("--git-dir", "--work-tree")):
            return None
        if option == "-C" and rest:
            current = resolve(current, rest.pop(0))
        elif option in GLOBAL_OPTIONS_WITH_VALUE and rest:
            rest.pop(0)
    return current


def invocations_with_dirs(tokens, base):
    """(directory, arguments) for every bare `git` token.

    A move is trusted only where the shell is sure to keep it for the git call:
    a `cd` or `pushd` that starts a command in a plain `&&` chain from the start
    of the text. After a move, any other separator — `;`, `|`, `&`, `||`, a
    newline, a paren, a backtick — may mean the cd did not run, ran in a
    subshell, or was undone, so the directory turns to None. So does a `popd`,
    and a `cd` or `pushd` anywhere the walk does not track, such as after `{`
    or `then`. None is never a guess: the caller checks every candidate.
    """
    found = []
    current = base
    moved = False
    at_start = True
    moving = False          # the last token was a tracked `cd` or `pushd`
    overridden = False      # a GIT_DIR= or GIT_WORK_TREE= prefix on this command
    args = None
    for token in tokens:
        if is_separator(token):
            if moving:
                current = None                    # a bare `cd` goes home
            if args is not None:
                where = None if overridden else git_dir(args, current)
                found.append((where, subcommand_args(args)))
                args = None
            if moved and token != "&&":
                current = None
            at_start, moving, overridden = True, False, False
            continue
        if args is not None:
            args.append(token)
        elif moving:
            current = resolve(current, token)
            moving = False
        elif token in ("cd", "pushd", "popd"):
            if at_start and token != "popd":
                moving = moved = True
            else:
                current, moved = None, True
        elif token == "git":
            args = []
        elif re.match(r"GIT_(DIR|WORK_TREE)=", token):
            overridden = True
        at_start = False
    if args is not None:
        where = None if overridden else git_dir(args, current)
        found.append((where, subcommand_args(args)))
    return found


def invocations(tokens, program="git"):
    """The arguments of every bare `program` token, `git` unless told otherwise.

    Bare is the whole test. Quoting collapses "how to git commit" into one
    token, and heredoc bodies are gone by now, so prose can never produce a
    `git` token on its own. Everything else is treated as a real invocation —
    `sudo git`, `VAR=x git`, `do git` inside a loop — because a guard that
    tries to list the wrappers it knows about will always miss one.

    `gh` gets the same rule, because `gh release create -n "..."` quoted in
    prose is just as much text. Its arguments go through the same walk: gh
    takes no options before its subcommand, so in practice the walk only
    drops redirections for it.
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
        elif token == program:
            args = []
    if args is not None:
        found.append(subcommand_args(args))
    return found


def main():
    command = sys.stdin.read()
    try:
        tokens = tokenise(strip_heredocs(command))
    except TooLong as err:
        sys.stderr.write("git-command.py: %s\n" % err)
        return 4
    except ValueError as err:
        sys.stderr.write("git-command.py: cannot parse the command: %s\n" % err)
        return 3
    if len(sys.argv) == 3 and sys.argv[1] == "--dir":
        for where, args in invocations_with_dirs(tokens, sys.argv[2]):
            print("%s\t%s" % (where or "", " ".join(args)))
        return 0
    for args in invocations(tokens):
        print(" ".join(args))
    return 0


if __name__ == "__main__":
    sys.exit(main())
