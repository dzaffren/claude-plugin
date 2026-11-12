#!/usr/bin/env bash
# PreToolUse[Bash] hook: block a commit message, tag message, release notes or
# title, PR body or title, or merge commit message that signs Claude's name.
# Judges the message text only. Subject format is verify-ship-gates.sh's job, so this stays safe in
# repos that do not use Conventional Commits.
set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -I -c 'import json,sys; [s.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n") for s in (sys.stdin, sys.stdout)]; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null) || { printf '%s\n' "Blocked: could not read the hook payload, so this command was not checked." "Run it again without unusual characters." >&2; exit 2; }
[ -z "$cmd" ] && exit 0

# Where the command starts, which places a relative message file: the hook's
# cwd, which follows the session's cd.
base=$(printf '%s' "$input" | python3 -I -c 'import json,sys; [s.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n") for s in (sys.stdin, sys.stdout)]; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)
[ -n "$base" ] || base="$PWD"

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# The text of every commit message, tag message, release notes and title, PR
# body and title, and merge commit message on the command line, via lib/git-command.py so that a
# trailer inside a quoted argument to some other command is text, not a
# message. Each line comes out as "<what it is><tab><line>" so the block can
# say which one carried it. A message the guard could not read comes out as
# "!unread<tab><what it is><tab><path as typed>", and one from stdin as
# "!stdin<tab><what it is><tab><option as typed>". Each blocks (D31).
# Exit 3 means the command would not parse; matching the raw text then
# over-blocks rather than under-blocks.
messages=$(ZUKO_COMMAND="$cmd" python3 -I - "$here" "$base" <<'PY' 2>/dev/null
import importlib.util
import os
import re
import sys

for stream in (sys.stdin, sys.stdout, sys.stderr):
    stream.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n")

path = os.path.join(sys.argv[1], "lib", "git-command.py")
spec = importlib.util.spec_from_file_location("git_command", path)
git_command = importlib.util.module_from_spec(spec)
spec.loader.exec_module(git_command)

# No commit message is anywhere near this long, and an unbounded read is how a
# guard turns into a hang.
MAX_MESSAGE_BYTES = 1 << 20

try:
    tokens = git_command.tokenise(
        git_command.strip_heredocs(os.environ["ZUKO_COMMAND"]))
except ValueError:
    sys.exit(3)

# Where the command starts. $PWD from Git Bash is a /c/... path.
base = git_command.native_path(sys.argv[2])

# The names a > or >> in this command writes. The write runs after this guard,
# so a message file of that name may still hold the last commit's text.
WRITTEN = {os.path.basename(target) for redirect, target in zip(tokens, tokens[1:])
           if git_command.is_redirection(redirect) and ">" in redirect} - {""}


def read_file(label, typed, option, where):
    """The text of a message file, or None once the line that says why the
    guard could not read it is printed. A line that starts with ! is a problem,
    never message text: no label starts with !."""
    if typed == "-":
        print("!stdin\t%s\t%s" % (label, option))
        return None
    path = None
    if not any(ch in typed for ch in "$`") and os.path.basename(typed) not in WRITTEN:
        path = git_command.native_path(os.path.expanduser(typed))
        if not os.path.isabs(path):
            path = os.path.join(where, path) if where else None
    # Only a regular file is opened: a fifo would make the guard wait.
    if path and os.path.isfile(path):
        try:
            with open(path, encoding="utf-8", errors="replace") as handle:
                return handle.read(MAX_MESSAGE_BYTES)
        except OSError:
            pass
    print("!unread\t%s\t%s" % (label, typed))
    return None


def emit(label, kind, value, option, where):
    if kind is None:
        return                      # an option's value that is not message text
    if kind == "file":
        value = read_file(label, value, option, where)
        if value is None:
            return
    if kind == "trailer":
        # git splits a --trailer at its first : or =, strips the spaces
        # around both parts, and writes "token: value".
        parts = re.split(r"[:=]", value, maxsplit=1)
        if len(parts) == 2:
            value = "%s: %s" % (parts[0].strip(), parts[1].strip())
    for line in value.split("\n"):
        print("%s\t%s" % (label, line))


def short_options(token, rest, letters, drop_equals, where):
    """git's rule for -am"x", which gh's -n"x" follows too: the letters before
    the one that takes a value are flags, everything after it is the value,
    and an empty tail takes the next argument. A letter whose value is
    optional, as in git's -S[<keyid>], takes only the tail. gh's flag parser
    also drops one "=" after the letter (-F=path reads path); git keeps it."""
    for index, letter in enumerate(token[1:], start=1):
        if letter not in letters:
            continue
        label, kind = letters[letter]
        if kind == "optional":
            return
        tail = token[index + 1:]
        if drop_equals and tail.startswith("="):
            tail = tail[1:]
        if tail:
            emit(label, kind, tail, "-" + letter, where)
        elif rest:
            emit(label, kind, rest.pop(0), "-" + letter, where)
        return


def long_option(name, longs, abbreviate):
    """git takes any unambiguous prefix of a long option (--mess is --message);
    gh's flag parser takes only the full name. An ambiguous prefix makes git
    stop with an error, so matching it too only ever over-blocks."""
    if name in longs:
        return longs[name]
    if abbreviate and len(name) > 2:
        for full, meaning in longs.items():
            if full.startswith(name):
                return meaning
    return None


def read_options(rest, longs, letters, where, drop_equals=False, abbreviate=False):
    """Emit every option value that is message text or names a message file.
    `where` is the directory the command runs in, which places a relative
    message file, or None when the text cannot say."""
    while rest:
        token = rest.pop(0)
        name, equals, value = token.partition("=")
        meaning = long_option(name, longs, abbreviate) if name.startswith("--") else None
        if meaning:
            label, kind = meaning
            if equals:
                emit(label, kind, value, name, where)
            elif rest:
                emit(label, kind, rest.pop(0), name, where)
        elif token.startswith("--"):
            continue
        elif token.startswith("-") and len(token) > 1:
            short_options(token, rest, letters, drop_equals, where)


# An option that takes a value which is not message text. It must still take
# its value: else a value that ends in t, b, m or F, as in -Bnext or -tm, reads
# as -t, -b, -m or -F and takes the next flag as its text (gh 2.101.0, the
# --help of gh release create, gh pr create, gh pr edit and gh pr merge; git
# 2.52.0, the -h of git commit, git tag and git merge). OPTIONAL is a short
# option whose value is optional, so it takes the rest of its word only.
VALUE = (None, None)
OPTIONAL = (None, "optional")


def git_table(label, longs, letters, trailer=False):
    """The long and short options of a git subcommand that writes a message.
    The message options come first, so an ambiguous prefix reads as one."""
    message = {"--message": (label, "text"), "--file": (label, "file")}
    if trailer:
        message["--trailer"] = (label, "trailer")
    return ({**message, **dict.fromkeys(longs, VALUE)},
            {"m": (label, "text"), "F": (label, "file"), **letters})


# git commit and git tag also write each --trailer into the message. git
# merge writes the merge commit message from -m and -F, and has no --trailer.
GIT_TABLES = {
    "commit": git_table(
        "commit message",
        ("--author", "--date", "--reedit-message", "--reuse-message", "--fixup",
         "--squash", "--template", "--cleanup", "--pathspec-from-file",
         "--unified", "--inter-hunk-context"),
        {"c": VALUE, "C": VALUE, "t": VALUE, "U": VALUE, "u": OPTIONAL,
         "S": OPTIONAL}, trailer=True),
    "tag": git_table(
        "tag message",
        ("--cleanup", "--local-user", "--contains", "--no-contains", "--merged",
         "--no-merged", "--sort", "--points-at", "--format"),
        {"u": VALUE, "n": OPTIONAL}, trailer=True),
    "merge": git_table(
        "merge message",
        ("--cleanup", "--strategy", "--strategy-option", "--into-name"),
        {"s": VALUE, "X": VALUE, "S": OPTIONAL}),
}

for where, args in git_command.invocations_with_dirs(tokens, base):
    if args and args[0] in GIT_TABLES:
        longs, letters = GIT_TABLES[args[0]]
        read_options(args[1:], longs, letters, where, abbreviate=True)

NOTES = ("release notes", "text")
NOTES_FILE = ("release notes", "file")
TITLE = ("release title", "text")
RELEASE_VALUES = ("--discussion-category", "--notes-start-tag", "--repo", "--target")

# "new" is gh's own alias for "create" (gh release create --help).
for where, args in git_command.invocations_with_dirs(tokens, base, program="gh"):
    if args[:1] == ["release"] and args[1:2] in (["create"], ["new"]):
        read_options(
            args[2:],
            {"--notes": NOTES, "--notes-file": NOTES_FILE, "--title": TITLE,
             **dict.fromkeys(RELEASE_VALUES, VALUE)},
            {"n": NOTES, "F": NOTES_FILE, "t": TITLE, "R": VALUE}, where,
            drop_equals=True)

BODY = ("PR body", "text")
BODY_FILE = ("PR body", "file")
PR_TITLE = ("PR title", "text")
MERGE = ("merge commit message", "text")
MERGE_FILE = ("merge commit message", "file")
CREATE_VALUES = ("--assignee", "--attach", "--base", "--head", "--label",
                 "--milestone", "--project", "--recover", "--repo", "--reviewer",
                 "--template")
EDIT_VALUES = ("--add-assignee", "--add-label", "--add-project", "--add-reviewer",
               "--attach", "--base", "--milestone", "--remove-assignee",
               "--remove-label", "--remove-project", "--remove-reviewer", "--repo")
MERGE_VALUES = ("--author-email", "--match-head-commit", "--repo")


def after_repo(args):
    """gh pr takes -R/--repo before its subcommand (gh pr --help), so
    `gh pr -R o/r create` is a create too. Drop it and its value."""
    while args:
        name, equals, _ = args[0].partition("=")
        if name == "--repo" or args[0] == "-R":
            args = args[1 if equals else 2:]
        elif args[0].startswith("-R"):
            args = args[1:]
        else:
            break
    return args


# "new" is gh's own alias for "create" (gh pr create --help). edit replaces an
# open PR's body and title the same way. merge writes the merge commit on the
# base branch from --subject and --body (gh pr merge --help) (D54).
for where, args in git_command.invocations_with_dirs(tokens, base, program="gh"):
    if args[:1] != ["pr"]:
        continue
    args = after_repo(args[1:])
    if args[:1] in (["create"], ["new"]):
        read_options(
            args[1:],
            {"--body": BODY, "--body-file": BODY_FILE, "--title": PR_TITLE,
             **dict.fromkeys(CREATE_VALUES, VALUE)},
            {"b": BODY, "F": BODY_FILE, "t": PR_TITLE, "a": VALUE, "B": VALUE,
             "H": VALUE, "l": VALUE, "m": VALUE, "p": VALUE, "r": VALUE,
             "T": VALUE, "R": VALUE}, where, drop_equals=True)
    elif args[:1] == ["edit"]:
        read_options(
            args[1:],
            {"--body": BODY, "--body-file": BODY_FILE, "--title": PR_TITLE,
             **dict.fromkeys(EDIT_VALUES, VALUE)},
            {"b": BODY, "F": BODY_FILE, "t": PR_TITLE, "B": VALUE, "m": VALUE,
             "R": VALUE}, where, drop_equals=True)
    elif args[:1] == ["merge"]:
        read_options(
            args[1:],
            {"--body": MERGE, "--body-file": MERGE_FILE, "--subject": MERGE,
             **dict.fromkeys(MERGE_VALUES, VALUE)},
            {"b": MERGE, "F": MERGE_FILE, "t": MERGE, "A": VALUE, "R": VALUE},
            where, drop_equals=True)
PY
)
case $? in
  0) found="$messages" ;;
  *) found=$(printf '%s\n' "$cmd" | awk '{ print "command\t" $0 }') ;;
esac

[ -z "$found" ] && exit 0

# A ! line is a message the guard could not read. Every other line is text.
problems=$(grep '^!' <<<"$found" || true)
found=$(grep -v '^!' <<<"$found" || true)

# The labels are fixed words, so matching the labelled line cannot misfire.
banned='co-authored-by:.*(claude|noreply@anthropic\.com)|claude-session:|https://claude\.(ai/code|com/claude-code)|generated with \[?claude code'
offending=$(printf '%s\n' "$found" | grep -iE "$banned" || true)
[ -z "$problems$offending" ] && exit 0

{
  printed=""
  while IFS=$'\t' read -r problem label typed; do
    [ -n "$problem" ] || continue
    typed=${typed%$'\r'}   # print() ends the line with \r\n on Windows
    case $label in
      "commit message" | "tag message" | "merge message") inline=-m ;;
      "release notes") inline=--notes ;;
      *) inline=--body ;;
    esac
    [ -n "$printed" ] && echo ""
    printed=yes
    if [ "$problem" = '!stdin' ]; then
      case $label in
        "release notes") comes=come ;;
        *) comes=comes ;;
      esac
      echo "Blocked: the $label $comes from stdin ($typed -). The guard cannot read stdin, so it did not check the text."
      echo ""
      echo "Give the message with $inline. Or write it to a file in a separate Bash call, before this command."
    else
      echo "Blocked: the guard could not read the $label file $typed, so it did not check the text."
      echo ""
      echo "Write the file in a separate Bash call, before this command. Or give the message with $inline."
    fi
  done <<<"$problems"
} >&2
[ -z "$offending" ] && exit 2

labels=$(printf '%s\n' "$offending" | cut -f1 | awk '!seen[$0]++')

{
  [ -n "$problems" ] && echo ""
  while IFS= read -r label; do
    case $label in
      "release notes") echo "Blocked: the release notes carry Claude attribution." ;;
      *) echo "Blocked: the $label carries Claude attribution." ;;
    esac
  done <<<"$labels"
  echo ""
  printf '%s\n' "$offending" | cut -f2- | sed 's/^/  /'
  echo ""
  echo "references/git-naming.md bans model attribution in commit messages, PR"
  echo "bodies, tag messages and release notes. Remove those lines and run it again."
  # Only commits get the harness's injected attribution, so only they get the
  # settings fix. A merge message is a commit's message, and an unparsed
  # command might be a commit.
  case $labels in
    *"commit message"* | *"merge message"* | *command*)
      echo ""
      echo "The harness re-injects the attribution instruction every session, so this will"
      echo "recur. To stop it at the source, set \`attribution\` in ~/.claude/settings.json:"
      echo ""
      echo '  { "attribution": { "commit": "", "pr": "", "sessionUrl": false } }'
      ;;
  esac
} >&2
exit 2
