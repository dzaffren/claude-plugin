#!/usr/bin/env python3
"""Say whether a shell command is the release commit `release.py cut` prepared.

Usage: release-commit.py <dir>    (the shell command on stdin)

block-dangerous.sh asks this before it blocks a commit on main (D30). `cut`
leaves a marker at git's `zuko-release` path naming the version, HEAD, and
every file it wrote. The commit passes only when the whole Bash call is one
plain `git commit -m ... [-m ...]`, its subject is `chore(release): v<version>`,
HEAD is still the marker's, and the staged files are exactly the marker's.

The whole call, because this runs before the call does: a `git add` before
the commit, an env prefix such as GIT_INDEX_FILE, a git option such as -c, or
a `$(...)` the shell splits into more arguments would each change what the
commit takes after the check has passed.

Exit 0  it is that commit
Exit 1  it tries to be a release commit and something does not match; the
        lines on stdout say what
Exit 3  the command will not parse
Exit 4  it does not try to be a release commit: no `chore(release):` subject
Exit 5  it tries to be one, but there is no marker for the current HEAD
"""
import importlib.util
import os
import shlex
import subprocess
import sys

MARKER = "zuko-release"
PREFIX = "chore(release):"

here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("git_command", os.path.join(here, "git-command.py"))
git_command = importlib.util.module_from_spec(spec)
spec.loader.exec_module(git_command)


def git(where, *args):
    return subprocess.run(["git", "-C", where] + list(args), capture_output=True, text=True)


def subject_of(args):
    """The first -m value, which git makes the subject; None without one."""
    for at, token in enumerate(args):
        if token == "-m" and at + 1 < len(args):
            return args[at + 1]
    return None


def whole_call(command):
    """True when the command is `git commit -m <message> [-m <message> ...]`
    and nothing else. One line, no comment, and no token the shell would
    expand or treat as an operator: `$`, a backtick, or punctuation."""
    if "\n" in command or "\r" in command:
        return False
    lex = shlex.shlex(command, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    try:
        tokens = list(lex)
    except ValueError:
        return False
    if any("$" in token or "`" in token or token.startswith("#") for token in tokens):
        return False
    if any(token and all(ch in lex.punctuation_chars for ch in token) for token in tokens):
        return False
    rest = tokens[2:]
    return (tokens[:2] == ["git", "commit"] and bool(rest) and len(rest) % 2 == 0
            and all(token == "-m" for token in rest[::2]))


def read_marker(where):
    """(version, head, files) from the marker, or None when it is missing or
    malformed."""
    path = git(where, "rev-parse", "--git-path", MARKER).stdout.strip()
    if not path:
        return None
    try:
        with open(os.path.join(where, path), encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return None
    if len(lines) < 3 or not lines[0].startswith("version ") or not lines[1].startswith("head "):
        return None
    return lines[0][len("version "):], lines[1][len("head "):], lines[2:]


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: release-commit.py <dir>\n")
        return 2
    where = sys.argv[1]
    command = sys.stdin.read()
    try:
        tokens = git_command.tokenise(git_command.strip_heredocs(command))
    except ValueError:
        return 3
    commits = [args for args in git_command.invocations(tokens) if args[:1] == ["commit"]]
    subject = subject_of(commits[0]) if commits else None
    if subject is None or not subject.startswith(PREFIX):
        return 4
    marker = read_marker(where)
    if marker is None:
        return 5
    version, head, files = marker
    if git(where, "rev-parse", "HEAD").stdout.strip() != head:
        return 5

    reasons = []
    if not whole_call(command):
        reasons.append("the release commit is the whole Bash call: one plain "
                       "git commit -m, staged in an earlier call")
    wanted = "%s v%s" % (PREFIX, version)
    if subject != wanted:
        reasons.append('subject is "%s", not "%s"' % (subject, wanted))
    staged = set(filter(None, git(where, "diff", "--cached", "--name-only", "-z").stdout.split("\0")))
    reasons += ["staged %s, which cut did not write" % name for name in sorted(staged - set(files))]
    reasons += ["cut wrote %s, which is not staged" % name for name in sorted(set(files) - staged)]
    if not reasons:
        return 0
    print("This is not the commit release.py cut prepared for v%s:" % version)
    for reason in reasons:
        print("  - " + reason)
    return 1


if __name__ == "__main__":
    sys.exit(main())
