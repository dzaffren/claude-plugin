#!/usr/bin/env bash
# PreToolUse[Bash] hook: block a commit message that signs Claude's name.
# Judges the message text only. Subject format is verify-ship-gates.sh's job,
# so this stays safe in repos that do not use Conventional Commits.
set -uo pipefail

cmd=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null) || exit 0
[ -z "$cmd" ] && exit 0

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# The text of every commit message on the command line, via lib/git-command.py
# so that a trailer inside a quoted argument to some other git subcommand is
# text, not a message. Exit 3 means the command would not parse; matching the
# raw text then over-blocks rather than under-blocks.
messages=$(ZUKO_COMMAND="$cmd" python3 - "$here" <<'PY' 2>/dev/null
import importlib.util
import os
import sys

path = os.path.join(sys.argv[1], "lib", "git-command.py")
spec = importlib.util.spec_from_file_location("git_command", path)
git_command = importlib.util.module_from_spec(spec)
spec.loader.exec_module(git_command)

try:
    tokens = git_command.tokenise(
        git_command.strip_heredocs(os.environ["ZUKO_COMMAND"]))
except ValueError:
    sys.exit(3)


def emit(kind, value):
    if kind == "text":
        print(value)
        return
    if value == "-":
        return                      # the message is on stdin, out of reach
    try:
        with open(value, encoding="utf-8", errors="replace") as handle:
            print(handle.read())
    except OSError:
        return                      # unreadable is a miss, not a crash


def short_options(token, rest):
    """git's own rule for -am"x": the letters before m are flags, everything
    after it is the value, and an empty tail takes the next argument."""
    for index, letter in enumerate(token[1:], start=1):
        kind = {"m": "text", "F": "file"}.get(letter)
        if kind is None:
            continue
        tail = token[index + 1:]
        if tail:
            emit(kind, tail)
        elif rest:
            emit(kind, rest.pop(0))
        return


for args in git_command.invocations(tokens):
    if not args or args[0] != "commit":
        continue
    rest = args[1:]
    while rest:
        token = rest.pop(0)
        if token in ("--message", "--file"):
            if rest:
                emit("text" if token == "--message" else "file", rest.pop(0))
        elif token.startswith("--message="):
            emit("text", token[len("--message="):])
        elif token.startswith("--file="):
            emit("file", token[len("--file="):])
        elif token.startswith("--"):
            continue
        elif token.startswith("-") and len(token) > 1:
            short_options(token, rest)
PY
)
case $? in
  0) subject="$messages" ;;
  *) subject="$cmd" ;;
esac

[ -z "$subject" ] && exit 0

banned='co-authored-by:.*(claude|noreply@anthropic\.com)|claude-session:|https://claude\.ai/code/session_|generated with claude code'
offending=$(printf '%s\n' "$subject" | grep -iE "$banned" || true)
[ -z "$offending" ] && exit 0

{
  echo "Blocked: the commit message carries Claude attribution."
  echo ""
  printf '%s\n' "$offending" | sed 's/^/  /'
  echo ""
  echo "references/git-naming.md bans model attribution in commit messages. Remove"
  echo "those lines and commit again."
  echo ""
  echo "The harness re-injects the attribution instruction every session, so this will"
  echo "recur. To stop it at the source, set \`attribution\` in ~/.claude/settings.json:"
  echo ""
  echo '  { "attribution": { "commit": "", "pr": "", "sessionUrl": false } }'
} >&2
exit 2
