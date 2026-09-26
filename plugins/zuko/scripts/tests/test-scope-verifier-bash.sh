# scripts/scope-verifier-bash.sh -- the PreToolUse guard that holds the
# finding-verifier's Bash to read-only `git diff` and `git show`.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.
#
# The refused options come from git 2.50.1's own help (`git help -m diff`,
# `git help -m show`):
#   --output=<file>                 writes the diff to a file
#   --ext-diff  "Allow an external diff helper to be executed."
#   --textconv  "Allow (or disallow) external text conversion filters to be run"
#   --show-signature  "Check the validity of a signed commit object by passing the
#                      signature to gpg --verify"
#   %G? %GG ...  "raw verification message from GPG for a signed commit"
#   --no-index  compares two paths on disk, outside the repo
# git 2.50.1 rejects abbreviated spellings of these (`git diff --out=x` and
# `git show --show-sig` both exit 129 or 128), but other versions accept any
# unambiguous prefix, so the guard refuses the prefixes too.

work=$(mktemp -d -p "$work")
guard="$scripts/scope-verifier-bash.sh"
VERIFIER="zuko:finding-verifier"

run_hook() {   # run_hook <agent_type or ""> <shell command>; sets $hook_err $hook_status
  local payload
  payload=$(ZUKO_AGENT="$1" ZUKO_CMD="$2" python3 -c '
import json, os
event = {"tool_name": "Bash", "tool_input": {"command": os.environ["ZUKO_CMD"]}}
if os.environ["ZUKO_AGENT"]:
    event["agent_type"] = os.environ["ZUKO_AGENT"]
    event["agent_id"] = "a0c29b1b8d45cd5a4"
print(json.dumps(event))')
  # perl's alarm, not coreutils timeout: macOS ships perl but not timeout.
  printf '%s' "$payload" | perl -e 'alarm shift; exec @ARGV' 5 bash "$guard" >/dev/null 2>"$work/err"
  hook_status=$?
  hook_err=$(cat "$work/err")
}

allows() {     # allows <command>: the verifier may run it
  run_hook "$VERIFIER" "$1"
  expect_exit 0 "$hook_status" "verifier may run: $1"
}

blocks() {     # blocks <command> <regex the message must match>
  run_hook "$VERIFIER" "$1"
  expect_exit 2 "$hook_status" "verifier is blocked from: $1"
  expect_match "$2" "$hook_err" "the block names what it saw in: $1"
  # Run 4: verifiers kept sending grep and find to Bash after being blocked.
  # Every block says which tool to use instead.
  expect_match 'To search or list files, use the Grep or Glob tool; to read a file, use Read\.' \
    "$hook_err" "the block points at Grep, Glob and Read for: $1"
}

# --- what the verifier needs: the diff and the base versions of lines ---
allows 'git diff main...HEAD'
allows 'git diff main...HEAD -- invoice_api/auth.py'
allows 'git show main:invoice_api/auth.py'
allows 'git show HEAD --stat'
allows 'git --no-pager diff main'
allows 'git -P show main:uv.lock'
allows 'git diff --text main'
allows "git show 'main:docs/a file.md'"
allows 'git show HEAD~1^:uv.lock'

# --- another program, or another git subcommand ---
blocks 'ls /' 'ls'
blocks 'cat invoice_api/auth.py' 'cat'
blocks 'git log --oneline' 'git log'
blocks 'git diff main; ls' "Saw: the character ';'"
blocks 'sudo git diff main' 'sudo'
blocks 'GIT_EXTERNAL_DIFF=x git diff main' 'GIT_EXTERNAL_DIFF'
blocks 'git' 'git'

# --- git's own options before the subcommand ---
blocks 'git -C /tmp diff' '\-C'
blocks 'git -c diff.external=x diff main' '\-c'
blocks 'git --config-env=diff.external=X diff' 'config-env'
blocks 'git --exec-path=/tmp diff' 'exec-path'
blocks 'git --git-dir=/tmp/other.git show HEAD' 'git-dir'

# --- subcommand options that run a program or write a file ---
blocks 'git diff --ext-diff main' 'ext-diff'
blocks 'git diff --ext main' '\-\-ext'
blocks 'git diff --textconv main' 'textconv'
blocks 'git diff --textc main' 'textc'
blocks 'git diff --output=/tmp/x main' 'output'
blocks 'git diff --output /tmp/x main' 'output'
blocks 'git diff --out=/tmp/x main' '\-\-out'
blocks 'git show --show-signature HEAD' 'show-signature'
blocks 'git show --show-sig HEAD' 'show-sig'
blocks 'git show --format=%G? HEAD' "Saw: the character '%'"
blocks 'git show --pretty=format:%GG HEAD' "Saw: the character '%'"
blocks 'git diff --no-index /etc/hosts invoice_api/db.py' 'no-index'
blocks 'git diff --help' 'help'

# --- H1: a `#` comment swallows the newline, so shlex read the next line as
# arguments and `ls /` ran. The raw command is allow-listed by character first.
blocks $'git diff main #\nls /' "Saw: the character '#'"
blocks $'git diff main#x\nls /' "Saw: the character '#'"
blocks $'git diff main\nls /' "Saw: the character '\\\\n'"
blocks 'git diff main -- a.py && git show main:a.py' "Saw: the character '&'"
blocks $'git diff\tmain' "Saw: the character '\\\\t'"
blocks 'git diff main\' "Saw: the character '\\\\\\\\'"

# --- H2: bash brace-expands these into refused options, which check_option
# never saw because the word does not start with `--`.
blocks 'git diff {--output=/tmp/x,main}' "Saw: the character '\\{'"
blocks 'git diff {--ext-diff,HEAD}' "Saw: the character '\\{'"
blocks 'git diff main -- *.py' "Saw: the character '\\*'"
blocks 'git diff main -- [ab].py' "Saw: the character '\\['"

# --- shell that runs or writes something else ---
blocks 'git diff main | sh' '\|'
blocks 'git diff main | cat' '\|'
blocks 'git diff main > /tmp/x' '>'
blocks 'git diff main 2>/tmp/err' '>'
blocks 'git diff $(echo main)' '\$'
blocks 'git diff `echo main`' '`'
blocks 'git diff $HOME' '\$'
blocks '(git diff main)' '\('
blocks 'git diff main &' '&'
blocks "git diff 'main" 'parse'

# --- every other caller is untouched ---
run_hook "" "ls /"
expect_exit 0 "$hook_status" "a main-thread ls, with no agent_type, is untouched"
run_hook "zuko:reviewer" "ls /"
expect_exit 0 "$hook_status" "the reviewer's ls is untouched"
run_hook "zuko:chunk-builder" "rm -r build"
expect_exit 0 "$hook_status" "a chunk-builder's command is untouched"

# --- H3: a payload over ARG_MAX made the env-var handoff fail with
# "python3: Argument list too long", exit 126, which let the call through.
huge() {       # huge <agent_type or ""> <command prefix> <file>: a 1.1 MB payload
  ZUKO_AGENT="$1" ZUKO_PREFIX="$2" python3 -c '
import json, os
event = {"tool_input": {"command": os.environ["ZUKO_PREFIX"] + "a" * 1100000}}
if os.environ["ZUKO_AGENT"]:
    event["agent_type"] = os.environ["ZUKO_AGENT"]
print(json.dumps(event))' >"$3"
}
huge "$VERIFIER" "ls / ; " "$work/huge-ls.json"
perl -e 'alarm shift; exec @ARGV' 20 bash "$guard" <"$work/huge-ls.json" >/dev/null 2>"$work/huge.err"
expect_exit 2 $? "a 1.1 MB verifier payload is blocked, not let through"
huge "$VERIFIER" "git show main:" "$work/huge-git.json"
perl -e 'alarm shift; exec @ARGV' 20 bash "$guard" <"$work/huge-git.json" >/dev/null 2>&1
expect_exit 0 $? "a 1.1 MB verifier git show is checked like any other"
huge "" "ls / ; " "$work/huge-main.json"
perl -e 'alarm shift; exec @ARGV' 20 bash "$guard" <"$work/huge-main.json" >/dev/null 2>&1
expect_exit 0 $? "a 1.1 MB main-thread payload is still untouched"

# A payload that will not parse is not the verifier's, so it passes; Claude
# Code always sends JSON, and failing open here cannot widen the verifier.
printf 'not json' | bash "$guard" >/dev/null 2>&1
expect_exit 0 $? "an unreadable payload exits 0"
