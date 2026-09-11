#!/usr/bin/env bash
# PreToolUse[Bash] hook: block destructive git/file commands.
set -uo pipefail

cmd=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null) || exit 0
[ -z "$cmd" ] && exit 0

deny() { echo "$1" >&2; exit 2; }

# What git is actually being asked to do, one invocation per line, so a command
# that only mentions "git commit" in a quoted argument or a heredoc body is not
# mistaken for one. A parse failure falls back to matching the raw text, which
# over-blocks rather than under-blocks.
git_args=$(printf '%s' "$cmd" | python3 "$(dirname "${BASH_SOURCE[0]}")/lib/git-command.py" 2>/dev/null)
if [ $? -eq 0 ]; then
  subject="$git_args"
  push_re='^push( .*)? (--force|--force-with-lease|-f)([[:space:]]|$)'
  commit_re='^commit([[:space:]]|$)'
else
  subject="$cmd"
  push_re='git push[^;|&]*(--force|--force-with-lease|[[:space:]]-f([[:space:]]|$))'
  commit_re='(^|[;&|[:space:]])git commit'
fi

if printf '%s\n' "$subject" | grep -qE "$push_re"; then
  deny "Blocked: force push rewrites shared history. Ask the user first."
fi

if printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)[[:space:]]+(/([[:space:]]|$)|/[a-z]+([[:space:]]|$)|~|\.\.)'; then
  deny "Blocked: recursive delete of a top-level or home path."
fi

if printf '%s\n' "$subject" | grep -qE "$commit_re"; then
  branch=$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" symbolic-ref --short HEAD 2>/dev/null || true)
  case "$branch" in
    main|master) deny "Blocked: committing directly on $branch. Create a branch first." ;;
  esac
fi

exit 0
