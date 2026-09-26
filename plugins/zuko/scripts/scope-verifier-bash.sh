#!/usr/bin/env bash
# PreToolUse[Bash] hook: hold zuko's finding-verifier to read-only `git diff` and
# `git show`. The verifier has Bash so it can see the diff and the base version
# of the lines it judges; a `tools:` pattern like `Bash(git diff *)` is not
# enforced (D8), so this hook is what scopes it.
#
# Acts only when the hook input's agent_type is zuko:finding-verifier. Every
# other caller, the main thread included, exits 0 untouched.
#
# An allow-list, never a deny-list: every command on the line must be `git`,
# then at most `--no-pager` or `-P`, then `diff` or `show`, with no option that
# runs a program or writes a file. Anything else blocks and names what it saw.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

ZUKO_PAYLOAD=$(cat) python3 - "$here" <<'PY'
import importlib.util
import json
import os
import sys

VERIFIER = "zuko:finding-verifier"

try:
    payload = json.loads(os.environ["ZUKO_PAYLOAD"])
except ValueError:
    sys.exit(0)                     # not a hook payload, so not the verifier's
if not isinstance(payload, dict) or payload.get("agent_type") != VERIFIER:
    sys.exit(0)

path = os.path.join(sys.argv[1], "lib", "git-command.py")
spec = importlib.util.spec_from_file_location("git_command", path)
git_command = importlib.util.module_from_spec(spec)
spec.loader.exec_module(git_command)

command = (payload.get("tool_input") or {}).get("command")


def block(saw):
    sys.stderr.write(
        "Blocked: the finding-verifier may run only read-only `git diff` and "
        "`git show`.\nSaw: %s\n" % saw)
    sys.exit(2)


if not isinstance(command, str) or not command.strip():
    block("an empty command")

# Substitution and variables expand into commands the parser cannot see.
if "$" in command:
    block("`$` (a variable or command substitution)")
if "`" in command:
    block("a backtick (command substitution)")

try:
    tokens = git_command.tokenise(git_command.strip_heredocs(command))
except ValueError as problem:
    block("a command that will not parse: %s" % problem)

# git's own options allowed before the subcommand. -C is refused: the verifier
# reads the repo it runs in and nothing else.
GLOBAL_ALLOWED = {"--no-pager", "-P"}
SUBCOMMANDS = {"diff", "show"}

# Options that run a program, write a file, or read outside the repo, from
# `git help -m diff` and `git help -m show` (git 2.50.1).
REFUSED = ("--ext-diff", "--textconv", "--output", "--show-signature",
           "--no-index", "--help")
# Real options that a prefix test would otherwise catch.
SAFE = {"--text", "--no-ext-diff", "--no-textconv", "--no-show-signature",
        "--output-indicator-new", "--output-indicator-old",
        "--output-indicator-context"}


def check_option(arg):
    if "%G" in arg:
        block("`%s` (a %%G format placeholder runs gpg)" % arg)
    if not arg.startswith("--"):
        return
    name = arg.split("=", 1)[0]
    if name in SAFE:
        return
    if name in REFUSED:
        block("`%s` (runs a program, writes a file, or reads outside the repo)" % name)
    # Some git versions take any unambiguous prefix of a long option.
    if len(name) >= 5 and any(full.startswith(name) for full in REFUSED):
        block("`%s` (an abbreviation of a refused option)" % name)


def check(words):
    if not words:
        return
    if words[0] != "git":
        block("`%s`" % words[0])
    rest = words[1:]
    while rest and rest[0].startswith("-"):
        if rest[0] not in GLOBAL_ALLOWED:
            block("git's own option `%s`" % rest[0])
        rest = rest[1:]
    if not rest:
        block("a bare `git`")
    if rest[0] not in SUBCOMMANDS:
        block("`git %s`" % rest[0])
    for arg in rest[1:]:
        if arg == "--":
            break                   # pathspecs from here on
        check_option(arg)


# `;`, `&&`, `||` and newlines join commands, each of which is checked. A pipe,
# a lone `&`, a subshell and every redirection block outright.
JOINERS = {";", "&&", "||", ""}
words = []
for token in tokens:
    if git_command.is_redirection(token):
        block("a redirection `%s`" % token)
    if git_command.is_separator(token):
        joiner = token.strip("\n")
        if joiner not in JOINERS or "\n" in joiner:
            if "|" in joiner:
                block("a pipe `%s`" % joiner)
            if "(" in joiner or ")" in joiner:
                block("a subshell `%s`" % joiner)
            block("`%s`" % joiner)
        check(words)
        words = []
        continue
    words.append(token)
check(words)
sys.exit(0)
PY
