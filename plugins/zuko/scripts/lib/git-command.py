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

# The same inside a double-quoted `$( )` or backticks, where the walk must
# know the whole delimiter: in `<<EOF-1` bash's is `EOF-1`, not `EOF`.
INNER_HEREDOC = re.compile(HEREDOC.pattern + r"(?=[ \t;&|()<>]|$)")

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
# `)`: after `$(date)` bash keeps `#x` in the word, and after a subshell's `)`
# it starts a comment, so a `#` there is unclear.
WORD_BREAKS = set(" \t;&|(<>")

# Inside `${...}`, `$'...'`, a backtick, or a `$(` in double quotes, bash's
# quotes and comments are not the walk's, so after one the walk is lost: it
# cannot tell whether a `#` at a word start starts a comment.
LOST_AFTER = ("${", "$'", "`")

# Each bracket the walk counts inside `(( ))`, `$(( ))`, `$[ ]` and `${ }`,
# and the one that closes it.
CLOSES = {"(": ")", "[": "]", "{": "}"}

# Two characters that open a heredoc, arithmetic or an expansion. bash joins
# them across a backslash-newline, but the walk reads one line at a time.
JOINED_OPENERS = ("((", "$(", "${", "$[", "<<")

# Text after an unclear `#` that would change what the walk reads next, if it
# is read as text: a quote, a backtick, a heredoc, or a line continuation.
CHANGES_THE_WALK = re.compile(r"""['"`]|<<|\\$""")

# git's own options, which sit before the subcommand. These take a value.
GLOBAL_OPTIONS_WITH_VALUE = {
    "-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path",
    "--super-prefix",
}


def openers_in(line, state):
    """Heredoc delimiters opened by this line, and where its comment starts
    (None for no comment). `state` carries the quote, whether the next
    character starts a word (None when unclear), and whether the walk is lost,
    from one line to the next.

    `echo '<<EOF'` opens nothing — it is a string. Only an unquoted `<<` does,
    which is why the quote state has to be carried in from the line before.
    A comment opens nothing either: `# it's` is no quote, `# <<EOF` no heredoc.

    A backslash that ends the line joins the next line to this word, as bash
    deletes the pair, so the next line starts a word only where the backslash
    stood at one: after `echo a\\`, a `#` on the next line is inside `a#`.

    An unclear `#` is read as text, so the rest of the line is checked too.
    When that text could change what the walk reads next, a quote or a
    heredoc that hides the lines after it, the command cannot be read.

    Inside `(( ))`, `$(( ))`, `$[ ]` and `${ }`, bash reads `<<` as a shift,
    and the line after it runs. But `((cat << X); (true))` is two subshells
    and a heredoc. `closers` holds the bracket that closes each one open
    since one of these started, and a `<<` while any is open cannot be read.
    A bracket closes only its own kind: in `${v:-)}` the `)` is text.
    `tail` is the character before a backslash-newline that ended the line
    before, so that a pair split across the two can be refused.

    Once the walk is lost, a `<<` inside double quotes may open a heredoc in
    a `$( )` or backticks, which bash reads and the walk does not. `inner`
    holds each one, as its delimiter, whether it is `<<-`, and whether it is
    quoted, until strip_heredocs finds the line that ends its body. One found
    on a line of such a body is text.
    """
    if state["tail"] + line[:1] in JOINED_OPENERS:
        raise ValueError("cannot tell what this backslash-newline joins; put the two lines on one line")
    delimiters = []
    quote, word_start, lost = state["quote"], state["word_start"], state["lost"]
    closers = state["closers"]
    opening = not state["inner"]
    at = 0
    while at < len(line):
        char = line[at]
        if quote:
            if char == quote:
                quote = None
            elif char == "\\" and quote == '"':
                at += 1
            elif quote == '"' and line.startswith(("$(", "${", "`"), at):
                lost = True
            elif (quote == '"' and lost and opening and line.startswith("<<", at)
                    and not line.startswith("<<<", at) and line[at - 1:at] != "<"):
                match = INNER_HEREDOC.match(line, at)
                if not match:
                    raise ValueError('cannot tell where a heredoc inside "$( )" ends; put the command in a file')
                state["inner"].append((match.group(2), match.group(0).startswith("<<-"),
                                       bool(match.group(1))))
            word_start = False
        elif char in "'\"":
            quote = char
            word_start = False
        elif char == "\\":
            if at == len(line) - 1:
                state.update(quote=quote, word_start=word_start, lost=lost, closers=closers,
                             tail=line[at - 1:at])
                return delimiters, None
            at += 1
            word_start = False
        elif char == "#" and (word_start is None or (word_start and lost)):
            if CHANGES_THE_WALK.search(line, at):
                raise ValueError("cannot tell whether a # starts a comment here; remove the comment")
            word_start = False
        elif char == "#" and word_start:
            state.update(quote=quote, word_start=True, lost=lost, closers=closers, tail="")
            return delimiters, at
        elif line.startswith("<<<", at):
            at += 2                      # a here-string, not a heredoc
            word_start = True
        else:
            lost = lost or line.startswith(LOST_AFTER, at)
            if closers and line.startswith("<<", at):
                raise ValueError("cannot tell whether this << starts a heredoc or shifts a number; put the command in a file")
            if line.startswith("((", at) or (char in "[{" and line[at - 1:at] == "$"):
                closers.append(CLOSES[char])
            elif closers and CLOSES.get(char) == closers[-1]:
                closers.append(closers[-1])
            elif closers and char == closers[-1]:
                closers.pop()
            match = HEREDOC.match(line, at)
            if match:
                delimiters.append(match.group(2))
                at = match.end() - 1
                word_start = False
            else:
                word_start = None if char == ")" else char in WORD_BREAKS
        at += 1
    state.update(quote=quote, word_start=True, lost=lost, closers=closers, tail="")
    return delimiters, None


def walk_state(state):
    return state["quote"], state["word_start"], state["lost"], tuple(state["closers"]), state["tail"]


def strip_heredocs(command):
    """Drop heredoc bodies and comments. They are raw text; shlex would read
    them as words.

    A heredoc inside a double-quoted `$( )` stays: its body is the text of
    the quoted word, as in `git commit -m "$(cat <<'EOF'`. bash skips the
    quotes in that body, but the walk and shlex read them. So each line of the
    body must leave the walk's state as it found it, or a `"` there would turn
    the lines after the heredoc into a string. A body that bash may join to
    the next line at a backslash, or that holds a heredoc the walk would drop,
    has no line the walk can trust as its end.
    """
    lines = command.split("\n")
    kept = []
    index = 0
    state = {"quote": None, "word_start": True, "lost": False, "closers": [], "tail": "",
             "inner": []}
    while index < len(lines):
        line = lines[index]
        body = bool(state["inner"])
        before = walk_state(state)
        delimiters, comment = openers_in(line, state)
        kept.append(line if comment is None else line[:comment])
        index += 1
        if state["inner"]:
            delimiter, dash, quoted = state["inner"][0]
            if body and walk_state(state) != before:
                raise ValueError('cannot tell whether the lines after a heredoc inside "$( )" are quoted; put the command in a file')
            if delimiters or (line.endswith("\\") and not (body and quoted)):
                raise ValueError('cannot tell where a heredoc inside "$( )" ends; put the command in a file')
            if body and (line.lstrip("\t") if dash else line) == delimiter:
                state["inner"].pop(0)
        for delimiter in delimiters:
            # Bodies are never scanned for quotes: an apostrophe in prose is
            # an apostrophe, not the start of a string.
            while index < len(lines) and lines[index].strip() != delimiter:
                index += 1
            if index >= len(lines):
                raise ValueError("heredoc %s is never closed" % delimiter)
            index += 1
    if state["quote"]:
        raise ValueError("unbalanced %s quote" % state["quote"])
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
