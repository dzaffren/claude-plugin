#!/usr/bin/env bash
# PreToolUse[Bash] hook: before a git commit, scan the staged diff for secrets.
set -uo pipefail

cmd=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null) || exit 0

# Same matcher as block-dangerous.sh: the git invocations actually being run,
# falling back to the raw text when the command cannot be parsed.
git_args=$(printf '%s' "$cmd" | python3 "$(dirname "${BASH_SOURCE[0]}")/lib/git-command.py" 2>/dev/null)
if [ $? -eq 0 ]; then
  subject="$git_args"
  commit_re='^commit([[:space:]]|$)'
else
  subject="$cmd"
  commit_re='(^|[;&|[:space:]])git commit'
fi
printf '%s\n' "$subject" | grep -qE "$commit_re" || exit 0

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
added=$(git -C "$dir" diff --cached 2>/dev/null | grep '^+' | grep -v '^+++' || true)
[ -z "$added" ] && exit 0

pattern='AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|glpat-[A-Za-z0-9_-]{20}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9_-]{20,}|AIza[A-Za-z0-9_-]{35}|(password|passwd|secret|api[_-]?key|access[_-]?token)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'[:space:]]{12,}'

hits=$(printf '%s\n' "$added" | grep -iEn "$pattern" | head -5 || true)
if [ -n "$hits" ]; then
  {
    echo "Blocked: the staged diff looks like it contains secrets:"
    echo "$hits"
    echo "Unstage the secret (git restore --staged <file>), move it to an untracked env file, then commit again. If this is a false positive, tell the user what matched and let them decide."
  } >&2
  exit 2
fi
exit 0
