#!/usr/bin/env python3
"""Print the git invocations a shell command actually runs.

Reads one shell command on stdin. Prints one line per `git` word — bare, or
a path to git or git.exe, or a path to git's dashed form `git-push` (D139) — its
arguments, unquoted and space-joined, with redirections and git's own options
dropped so the subcommand comes first. A preceding word does not hide it:
`sudo git commit` and `VAR=x git commit` both count. A `git commit` inside a
quoted argument, a heredoc body or a comment is text, not a command, so it is
not printed. A comment follows bash's rule: it starts at an unquoted `#` at the
start of a word, so the `#` in `x#` or `${#name}` is part of the word.

A command that bash runs from inside another one is a command too (D138): a
`$( )` or backtick in double quotes or in an unquoted heredoc body, the
string of a `bash -c`, and the words after `eval`. So is the command that git
runs for an alias set with `-c alias.NAME=VALUE` (D140). An alias whose value
the text does not show is refused.

With `--dir <base>`, each line is prefixed with the directory that invocation
runs in and a tab: `<base>` moved by a `cd` or `pushd` earlier in a plain `&&`
chain, then by git's own `-C`. The prefix is empty when the text cannot say
where git runs, and the caller must then judge every directory it could be.

Exit 0 with or without output. Exit 3 when the command cannot be parsed, with
the reason on stderr. bash still runs the lines before an unclosed quote, and an
unclosed heredoc to the end of the text, so the caller must block it (D52).
Exit 4 when it is over the length limit.
"""
import importlib.util
import os
import re
import shlex
import subprocess
import sys

# By its path, not `import program`: a hook that loads this file from
# `python3 -` has the project folder first on sys.path.
_spec = importlib.util.spec_from_file_location(
    "program", os.path.join(os.path.dirname(os.path.abspath(__file__)), "program.py"))
program = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(program)

# <<EOF, <<-EOF, <<'EOF', <<"EOF".
HEREDOC = re.compile(r'<<-?[ \t]*(["\']?)(\w+)\1')

# The same inside a double-quoted `$( )` or backticks, where the walk must
# know the whole delimiter: in `<<EOF-1` bash's is `EOF-1`, not `EOF`.
INNER_HEREDOC = re.compile(HEREDOC.pattern + r"(?=[ \t\n;&|()<>]|$)")

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

# Each nested command is parsed again, one level deeper. Past this depth the
# command is refused, as block-pentest-target.sh refuses shells nested deeper.
MAX_NESTING = 3

# The shells whose -c string is a command, as block-pentest-target.sh lists them.
SHELLS = {"bash", "sh", "zsh", "dash", "ksh", "fish"}

# Inside backticks, bash drops a backslash before `$`, a backtick or a
# backslash, so `\`` there is a nested backtick.
BACKTICK_ESCAPE = re.compile(r"\\([$`\\])")

# NAME=value before a command.
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")

# A -c option group: -c, -lc, -ec.
SHELL_C = re.compile(r"^-[A-Za-z]*c[A-Za-z]*$")

# Words that can stand before `eval` where bash still runs it as a command:
# a keyword, `command`, `builtin` or `time`. As any other word's argument,
# as in `git log -S eval`, it is text.
EVAL_LEADS = {"command", "builtin", "time", "!", "if", "then", "else", "elif",
              "do", "while", "until", "{"}

# Shell options that take the next word as their value.
SHELL_OPTIONS_WITH_VALUE = {"-o", "+o", "-O", "+O", "--rcfile", "--init-file"}

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
# git 2.52.0 also takes --attr-source's, --config-env's and --shallow-file's
# as the next word.
GLOBAL_OPTIONS_WITH_VALUE = {
    "-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path",
    "--super-prefix", "--attr-source", "--config-env", "--shallow-file",
}

# `-c alias.NAME=VALUE`. Alias names ignore case: `alias.P` sets `p`.
ALIAS_OPTION = re.compile(r"^alias\.([^=]+)=(.*)$", re.S | re.I)

# Where a config key `alias.NAME` stands in a word: the whole word, as `git
# config` takes it, after the `=` of `GIT_CONFIG_KEY_0=` or `--config-env=`, or
# in quotes, as GIT_CONFIG_PARAMETERS holds it. A message that only mentions
# `alias.p` in a sentence does not match.
ALIAS_KEY = r"(^|[='])alias\.%s('?=|'?$)"


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
    on a line of such a body counts too: bash may have ended that body already
    (at `EOF)`, or at a closing backtick), or never opened it (`<<` in single
    quotes or `${ }`), and then the `<<` opens a real heredoc.
    """
    if state["tail"] + line[:1] in JOINED_OPENERS:
        raise ValueError("cannot tell what this backslash-newline joins; put the two lines on one line")
    delimiters = []
    quote, word_start, lost = state["quote"], state["word_start"], state["lost"]
    closers = state["closers"]
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
            elif (quote == '"' and lost and line.startswith("<<", at)
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
            match = INNER_HEREDOC.match(line, at)
            if not match and line.startswith("<<", at):
                # A delimiter read only in part (`<<E-F`), or quoted in a form
                # the walk does not read (`<<'E-F'`, `<<\EOF`), hides where
                # bash ends the body, and the lines after it.
                word = re.split(r"[ \t;&|()<>]", line[at + 2:].lstrip("-").lstrip(" \t"), 1)[0]
                raise ValueError("cannot tell where heredoc %s ends; put the command in a file"
                                 % (word or "after <<"))
            if match:
                delimiters.append((match.group(2), match.group(0).startswith("<<-"),
                                   bool(match.group(1))))
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

    bash runs each `$( )` and backtick in the body of a heredoc whose
    delimiter is not quoted. The command in each one, with its own heredoc
    bodies and comments dropped, is added at the end as lines of their own,
    so tokenise reads it as a command.
    """
    lines = command.split("\n")
    kept = []
    found = []
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
        for delimiter, dash, quoted in delimiters:
            # Bodies are never scanned for quotes: an apostrophe in prose is
            # an apostrophe, not the start of a string. The end is the line
            # bash compares: the delimiter alone, or after tabs for `<<-`.
            start = index
            while index < len(lines) and (lines[index].lstrip("\t") if dash else lines[index]) != delimiter:
                index += 1
            if index >= len(lines):
                raise ValueError("heredoc %s is never closed" % delimiter)
            if not quoted:
                found.extend(within_recursion(body_commands, "\n".join(lines[start:index])))
            index += 1
    if state["quote"]:
        raise ValueError("unbalanced %s quote" % state["quote"])
    return "\n".join(kept + found)


def within_recursion(scan, text):
    """scan(text), with Python's recursion limit read as a parse failure:
    each nested `$( )` is one more call, and every caller handles ValueError."""
    try:
        return scan(text)
    except RecursionError:
        raise ValueError("substitutions nested too deep; put the inner command in a file")


def substitution_end(text, at):
    """The index after the `)` or backtick that closes the `$(` or backtick
    at `at`, as bash reads it.

    Inside `$( )` bash starts a new command: its own quotes, nested `$( )`
    and backticks, comments and heredoc bodies, so a `)` in any of them does
    not close it. A `case` there has a `)` that closes nothing, so it is
    refused. Inside backticks, a backslash escapes the next character, and the
    next backtick closes it.
    """
    if text[at] == "`":
        index = at + 1
        while index < len(text):
            if text[index] == "\\":
                index += 1
            elif text[index] == "`":
                return index + 1
            index += 1
        raise ValueError("a backtick is never closed")
    index = at + 2
    depth = 1
    heredocs = []
    word_start = True
    while index < len(text):
        char = text[index]
        if char == "\n" and heredocs:
            index = heredoc_bodies_end(text, index + 1, heredocs)
            heredocs = []
            word_start = True
            continue
        if char == "\\":
            index += 2
            word_start = False
            continue
        if char == "'":
            close = text.find("'", index + 1)
            if close < 0:
                raise ValueError("a ' quote inside $( ) is never closed")
            index = close + 1
        elif char == '"':
            index = quoted_end(text, index + 1, [])
        elif text.startswith("$'", index):
            index = ansi_quoted_end(text, index + 2)
        elif text.startswith("${", index):
            index = parameter_end(text, index)
        elif char == "`" or text.startswith("$(", index):
            index = arithmetic_end(text, index, []) or substitution_end(text, index)
        elif char == "#" and word_start:
            newline = text.find("\n", index)
            index = len(text) if newline < 0 else newline
            continue
        elif text.startswith("<<", index) and not text.startswith("<<<", index):
            match = INNER_HEREDOC.match(text, index)
            if not match:
                raise ValueError("cannot tell where a heredoc inside $( ) ends; put the command in a file")
            heredocs.append((match.group(2), match.group(0).startswith("<<-")))
            index = match.end()
        elif text.startswith("<<<", index):
            index += 3
        elif word_start and re.match(r"case[ \t\n]", text[index:index + 5]):
            raise ValueError("cannot tell where a $( ) with a case in it ends; put the command in a file")
        else:
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    return index + 1
            word_start = char in WORD_BREAKS or char in "\n)"
            index += 1
            continue
        word_start = False
    raise ValueError("a $( ) is never closed")


def heredoc_bodies_end(text, index, heredocs):
    """The index after the bodies of `heredocs`, which start at `index`.

    bash 5.1 also ends a body in `$( )` at a line such as `EOF)`, which other
    versions read as body text, so a line that starts with the delimiter and
    is not the delimiter alone is refused.
    """
    for delimiter, dash in heredocs:
        while True:
            if index >= len(text):
                raise ValueError("heredoc %s inside $( ) is never closed" % delimiter)
            newline = text.find("\n", index)
            end = len(text) if newline < 0 else newline
            line = text[index:end]
            line = line.lstrip("\t") if dash else line
            index = end + 1
            if line == delimiter:
                break
            if line.startswith(delimiter):
                raise ValueError("cannot tell where heredoc %s inside $( ) ends; put the command in a file" % delimiter)
    return min(index, len(text))


def quoted_end(text, index, found):
    """The index after the `"` that closes a double-quoted word whose text
    starts at `index`. The text of each `$( )` and backtick in it goes on
    `found`."""
    while index < len(text):
        char = text[index]
        if char == "\\":
            index += 2
            continue
        if char == '"':
            return index + 1
        if char == "`" or text.startswith("$(", index):
            index = substitution_or_arithmetic_end(text, index, found)
            continue
        index += 1
    raise ValueError('a " quote is never closed')


def substitution_or_arithmetic_end(text, at, found):
    """The index after the `$( )`, backtick or `$(( ))` at `at`. A
    substitution's text goes on `found`, and so does each one in arithmetic."""
    end = arithmetic_end(text, at, found)
    if end is None:
        end = substitution_end(text, at)
        found.append(text[at:end])
    return end


def arithmetic_end(text, at, found):
    """The index after the `))` that closes the `$((` at `at`, or None when it
    is not arithmetic. A `<<` there is a shift. The text of each `$( )` and
    backtick in it goes on `found`.

    bash reads `$((git push) )` and `$((git push); true)` as a `$( )` that
    starts with a subshell: the `(` after `$(` closes with no `)` right after
    it. Then it is not arithmetic.
    """
    if not text.startswith("$((", at):
        return None
    inner = []
    index = at + 3
    depth = 2
    while index < len(text):
        char = text[index]
        if char == "\\":
            index += 2
            continue
        if char == "`" or text.startswith("$(", index):
            index = substitution_or_arithmetic_end(text, index, inner)
            continue
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 1:
                if text[index + 1:index + 2] != ")":
                    return None
                found.extend(inner)
                return index + 2
        index += 1
    return None


def parameter_end(text, at):
    """The index after the `}` that closes the `${` at `at`. A `)` in it,
    as in `${x:-)}`, does not close a `$( )` around it."""
    index = at + 2
    while index < len(text):
        char = text[index]
        if char == "\\":
            index += 2
        elif char == "'":
            close = text.find("'", index + 1)
            if close < 0:
                raise ValueError("a ' quote inside ${ } is never closed")
            index = close + 1
        elif char == '"':
            index = quoted_end(text, index + 1, [])
        elif text.startswith("${", index):
            index = parameter_end(text, index)
        elif char == "`" or text.startswith("$(", index):
            index = substitution_or_arithmetic_end(text, index, [])
        elif char == "}":
            return index + 1
        else:
            index += 1
    raise ValueError("a ${ } is never closed")


def ansi_quoted_end(text, index):
    """The index after the `'` that closes a `$'...'` word, where a backslash
    escapes the next character."""
    while index < len(text):
        if text[index] == "\\":
            index += 2
            continue
        if text[index] == "'":
            return index + 1
        index += 1
    raise ValueError("a $' quote is never closed")


def body_commands(body):
    """The command in each `$( )` and backtick of an unquoted heredoc body,
    with its own heredoc bodies and comments dropped. bash reads quotes there
    as text, and a backslash escapes `$`, a backtick or a backslash."""
    found = []
    index = 0
    while index < len(body):
        if body[index] == "\\":
            index += 2
        elif body[index] == "`" or body.startswith("$(", index):
            index = substitution_or_arithmetic_end(body, index, found)
        else:
            index += 1
    return [strip_heredocs(inner_command(sub)) for sub in found]


def quoted_substitutions(text):
    """The text inside each `$( )` and backtick that sits in double quotes.

    An unquoted one is not taken: shlex splits it at its `(` or backtick, so
    the walk already reads the command in it. Its quotes are the walk's
    quotes, so this walk goes on through it.
    """
    found = []
    index = 0
    while index < len(text):
        char = text[index]
        if char == "\\":
            index += 2
        elif text.startswith("$'", index):
            index = ansi_quoted_end(text, index + 2)
        elif char == "'":
            close = text.find("'", index + 1)
            if close < 0:
                raise ValueError("unbalanced ' quote")
            index = close + 1
        elif char == '"':
            index = quoted_end(text, index + 1, found)
        else:
            index += 1
    return [inner_command(sub) for sub in found]


def inner_command(substitution):
    """The command inside a `$( )` or backtick, as written in the text."""
    if substitution.startswith("`"):
        return BACKTICK_ESCAPE.sub(r"\1", substitution[1:-1])
    return substitution[2:-1]


def shell_strings(tokens):
    """The command string of each `bash -c` and the like, and the words after
    each `eval` that bash runs as a command, joined as eval joins them."""
    found = []
    words = []
    for token in tokens + ["\n"]:
        if not is_separator(token):
            words.append(token)
            continue
        for at, word in enumerate(words):
            if word == "eval" and all(lead in EVAL_LEADS or ASSIGNMENT.match(lead)
                                      for lead in words[:at]):
                found.append(" ".join(words[at + 1:]))
                break
            if os.path.basename(word) in SHELLS:
                string = shell_string(words[at + 1:])
                if string is not None:
                    found.append(string)
        words = []
    return found


def shell_string(args):
    """The string a shell runs from -c: its first word that is not an option,
    when a -c group is among its options. `--` ends the options, and
    `-o pipefail`, `-O extglob` and `--rcfile f` take a value."""
    has_c = False
    rest = list(args)
    while rest:
        word = rest.pop(0)
        if word in ("--", "-"):
            break
        if word.startswith(("-", "+")):
            has_c = has_c or bool(SHELL_C.match(word))
            if word in SHELL_OPTIONS_WITH_VALUE and rest:
                rest.pop(0)
            continue
        return word if has_c else None
    return rest[0] if has_c and rest else None


def alias_strings(tokens):
    """For each git call whose subcommand is an alias that the call sets with
    `-c alias.NAME=VALUE`, the command git runs for it (D140). A plain value is
    the same words with the alias replaced, so the next parse reads a chain.
    A `!` value is a shell command with the call's arguments after it, in a
    directory the walk cannot know. The call as written stays, because git
    ignores an alias that has a builtin's name.

    An alias the text names but does not show the value of, as in
    `--config-env alias.p=X`, `GIT_CONFIG_KEY_0=alias.p` or `git config
    alias.p push`, raises ValueError, and so does a value with `$` or a
    backtick: shlex has dropped the quotes that say whether bash expands it."""
    found = []
    words = []
    for index, token in enumerate(tokens + ["\n"]):
        if not is_separator(token):
            words.append((index, token))
            continue
        for at, (_, word) in enumerate(words):
            if program_word(word, "git") != []:
                continue
            aliases = {}
            read = set()
            at_sub = at + 1
            while at_sub < len(words):
                option = words[at_sub][1]
                if is_redirection(option):
                    at_sub += 2
                elif option.isdigit() and at_sub + 1 < len(words) and is_redirection(words[at_sub + 1][1]):
                    at_sub += 1
                elif option.startswith("-"):
                    if option in GLOBAL_OPTIONS_WITH_VALUE and at_sub + 1 < len(words):
                        value_at, value = words[at_sub + 1]
                        alias = ALIAS_OPTION.match(value) if option == "-c" else None
                        if alias and not any(ch in alias.group(2) for ch in "$`"):
                            aliases[alias.group(1).lower()] = alias.group(2)
                            read.add(value_at)
                        at_sub += 2
                    else:
                        at_sub += 1
                else:
                    break
            if at_sub >= len(words):
                continue
            name = words[at_sub][1].lower()
            named = re.compile(ALIAS_KEY % re.escape(name), re.I)
            if any(named.search(other) for other_at, other in enumerate(tokens)
                   if other_at not in read):
                raise ValueError("the git alias %s gets a value this guard cannot read; "
                                 "write out the command it stands for" % name)
            if name not in aliases:
                continue
            value = aliases[name]
            plain = [word for _, word in words]
            if value.startswith("!"):
                found.append('cd "$GIT_PREFIX" && %s %s' % (value[1:], shlex.join(plain[at_sub + 1:])))
            else:
                found.append(shlex.join(plain[:at_sub] + shlex.split(value) + plain[at_sub + 1:]))
        words = []
    return found


def tokenise(command, depth=0):
    """The words of `command`, then, after a newline token, the words of each
    command nested in it: a `$( )` or backtick in double quotes, the string of
    a `bash -c`, and the words after `eval` (D138). A newline is a separator,
    so each caller judges a nested command as one of its own."""
    command = CONTINUATION.sub("", command)
    if len(command) > MAX_COMMAND_CHARS:
        raise TooLong("the command is over %d characters" % MAX_COMMAND_CHARS)
    lex = shlex.shlex(command, posix=True, punctuation_chars="();<>|&`\n")
    lex.whitespace_split = True
    lex.whitespace = " \t\r"
    lex.commenters = ""                  # strip_heredocs drops comments, as bash reads them
    tokens = list(lex)
    nested = (within_recursion(quoted_substitutions, command) + shell_strings(tokens)
              + alias_strings(tokens))
    if nested and depth >= MAX_NESTING:
        raise ValueError("commands nested more than %d deep; put the inner command in a file" % MAX_NESTING)
    for inner in nested:
        tokens.append("\n")
        tokens.extend(tokenise(strip_heredocs(inner), depth + 1))
    return tokens


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


def native_path(path):
    """`path` as this Python can open it.

    Git Bash converts `/tmp/x` to `C:/.../Temp/x` only when it passes a path to
    a program as an argument. A hook gets the command as text, so native
    Windows Python reads `/tmp/x` as `\\tmp\\x` on the current drive. On Windows
    a path that starts with `/` goes through the `cygpath -m` on PATH, as one
    argument with no shell. Any failure, a cygpath that is not on PATH, and
    every other OS give the path back unchanged.
    """
    if os.name != "nt" or not path.startswith("/"):
        return path
    try:
        result = subprocess.run(program.argv(["cygpath", "-m", "--", path]), capture_output=True,
                                encoding="utf-8", timeout=5)
    except (OSError, subprocess.SubprocessError, ValueError):
        return path
    converted = result.stdout.strip()
    return converted if result.returncode == 0 and converted else path


def resolve(current, path):
    """`current` moved to `path`, or None when the text cannot say where.

    An absolute path needs no `current`: `git -C /repo` is known even after a
    move the walk lost track of.
    """
    if not path or any(ch in path for ch in "$`"):
        return None
    path = native_path(os.path.expanduser(path))
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


def program_word(token, program):
    """The arguments a call of `program` starts with when bash runs `token`, or
    None. bash runs the same program from a path, and Windows from any case and
    with `.exe`, so the last part of a `/` or `\\` path is the name (D139). With
    a path, git's dashed form `git-push` is `git push`. Without one it is text,
    as in `grep -rn git-commit docs/`."""
    parts = re.split(r"[/\\]", token)
    name = parts[-1].lower()
    if name.endswith(".exe"):
        name = name[:-len(".exe")]
    if name == program:
        return []
    if program == "git" and len(parts) > 1 and name.startswith("git-") and len(name) > len("git-"):
        return [name[len("git-"):]]
    return None


def invocations_with_dirs(tokens, base, program="git"):
    """(directory, arguments) for every `program` word, `git` unless
    told otherwise. git's own options and a GIT_DIR= prefix apply to git only.

    A move is trusted only where the shell is sure to keep it for the git call:
    a `cd` or `pushd` that starts a command in a plain `&&` chain from the start
    of the text. After a move, any other separator — `;`, `|`, `&`, `||`, a
    newline, a paren, a backtick — may mean the cd did not run, ran in a
    subshell, or was undone, so the directory turns to None. So does a `popd`,
    and a `cd` or `pushd` anywhere the walk does not track, such as after `{`
    or `then`. None is never a guess: the caller checks every candidate.
    """
    def where(args):
        if program != "git":
            return current
        return None if overridden else git_dir(args, current)

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
                found.append((where(args), subcommand_args(args)))
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
        elif (start := program_word(token, program)) is not None:
            args = start
        elif re.match(r"GIT_(DIR|WORK_TREE)=", token):
            overridden = True
        at_start = False
    if args is not None:
        found.append((where(args), subcommand_args(args)))
    return found


def invocations(tokens, program="git"):
    """The arguments of every `program` word, `git` unless told otherwise: the
    bare name, or a path to it, as `program_word` reads it.

    That is the whole test. Quoting collapses "how to git commit" into one
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
        elif (start := program_word(token, program)) is not None:
            args = start
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
    # One call per line, for the shell guards. A newline inside a quoted word
    # prints as a space, as the space between words does, so one call never
    # splits into two lines that each miss the check.
    if len(sys.argv) == 3 and sys.argv[1] == "--dir":
        for where, args in invocations_with_dirs(tokens, sys.argv[2]):
            print(("%s\t%s" % (where or "", " ".join(args))).replace("\n", " "))
        return 0
    for args in invocations(tokens):
        print(" ".join(args).replace("\n", " "))
    return 0


if __name__ == "__main__":
    # UTF-8 with LF on every OS; a byte that is not UTF-8 goes out as it came (D98, D99).
    for stream in (sys.stdin, sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n")
    sys.exit(main())
