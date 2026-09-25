#!/usr/bin/env bash
# PreToolUse[Bash] hook: block a commit message, tag message, or release notes
# or title that signs Claude's name. Judges the message text only. Subject
# format is verify-ship-gates.sh's job, so this stays safe in repos that do not
# use Conventional Commits.
set -uo pipefail

cmd=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null) || exit 0
[ -z "$cmd" ] && exit 0

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# The text of every commit message, tag message, and release notes and title on
# the command line, via lib/git-command.py so that a trailer inside a quoted
# argument to some other command is text, not a message. Each line comes out
# as "<what it is><tab><line>" so the block can say which one carried it.
# Exit 3 means the command would not parse; matching the raw text then
# over-blocks rather than under-blocks.
messages=$(ZUKO_COMMAND="$cmd" python3 - "$here" <<'PY' 2>/dev/null
import importlib.util
import os
import sys

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


def emit(label, kind, value):
    if kind == "file":
        if not os.path.isfile(value):
            return                  # stdin, a fifo, a device: never readable
        try:
            with open(value, encoding="utf-8", errors="replace") as handle:
                value = handle.read(MAX_MESSAGE_BYTES)
        except OSError:
            return                  # unreadable is a miss, not a crash
    for line in value.split("\n"):
        print("%s\t%s" % (label, line))


def short_options(token, rest, letters):
    """git's rule for -am"x", which gh's -n"x" follows too: the letters before
    the one that takes a value are flags, everything after it is the value,
    and an empty tail takes the next argument."""
    for index, letter in enumerate(token[1:], start=1):
        if letter not in letters:
            continue
        label, kind = letters[letter]
        tail = token[index + 1:]
        if tail:
            emit(label, kind, tail)
        elif rest:
            emit(label, kind, rest.pop(0))
        return


def read_options(rest, longs, letters):
    """Emit every option value that is message text or names a message file."""
    while rest:
        token = rest.pop(0)
        name, equals, value = token.partition("=")
        if name in longs:
            label, kind = longs[name]
            if equals:
                emit(label, kind, value)
            elif rest:
                emit(label, kind, rest.pop(0))
        elif token.startswith("--"):
            continue
        elif token.startswith("-") and len(token) > 1:
            short_options(token, rest, letters)


# git commit and git tag take a message through the same four options.
GIT_LABELS = {"commit": "commit message", "tag": "tag message"}

for args in git_command.invocations(tokens):
    if args and args[0] in GIT_LABELS:
        label = GIT_LABELS[args[0]]
        read_options(
            args[1:],
            {"--message": (label, "text"), "--file": (label, "file")},
            {"m": (label, "text"), "F": (label, "file")})

NOTES = ("release notes", "text")
NOTES_FILE = ("release notes", "file")
TITLE = ("release title", "text")

for args in git_command.invocations(tokens, program="gh"):
    if args[:2] == ["release", "create"]:
        read_options(
            args[2:],
            {"--notes": NOTES, "--notes-file": NOTES_FILE, "--title": TITLE},
            {"n": NOTES, "F": NOTES_FILE, "t": TITLE})
PY
)
case $? in
  0) found="$messages" ;;
  *) found=$(printf '%s\n' "$cmd" | awk '{ print "command\t" $0 }') ;;
esac

[ -z "$found" ] && exit 0

# The labels are fixed words, so matching the labelled line cannot misfire.
banned='co-authored-by:.*(claude|noreply@anthropic\.com)|claude-session:|https://claude\.(ai/code|com/claude-code)|generated with \[?claude code'
offending=$(printf '%s\n' "$found" | grep -iE "$banned" || true)
[ -z "$offending" ] && exit 0

labels=$(printf '%s\n' "$offending" | cut -f1 | awk '!seen[$0]++')

{
  while IFS= read -r label; do
    case $label in
      "release notes") echo "Blocked: the release notes carry Claude attribution." ;;
      *) echo "Blocked: the $label carries Claude attribution." ;;
    esac
  done <<<"$labels"
  echo ""
  printf '%s\n' "$offending" | cut -f2- | sed 's/^/  /'
  echo ""
  echo "references/git-naming.md bans model attribution in commit messages, tag"
  echo "messages and release notes. Remove those lines and run it again."
  # Only commits get the harness's injected attribution, so only they get the
  # settings fix. An unparsed command might be a commit.
  case $labels in
    *"commit message"* | *command*)
      echo ""
      echo "The harness re-injects the attribution instruction every session, so this will"
      echo "recur. To stop it at the source, set \`attribution\` in ~/.claude/settings.json:"
      echo ""
      echo '  { "attribution": { "commit": "", "pr": "", "sessionUrl": false } }'
      ;;
  esac
} >&2
exit 2
