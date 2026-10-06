#!/usr/bin/env bash
# PreToolUse[Bash] hook: before a git commit, scan the staged diff for secrets.
set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null) || { printf '%s\n' "Blocked: could not read the hook payload, so this command was not checked." "Run it again without unusual characters." >&2; exit 2; }

# Where the command starts: the hook's cwd, which follows the session's cd.
base=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)
project="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -n "$base" ] || base="$project"

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

# Scan the staged diff each commit takes: the directory it runs in, as
# block-dangerous.sh works it out. Unknown or unparsed scans both the start and
# the project dir — never less than the project dir alone.
anywhere="$base"$'\n'"$project"
commit_dirs="$anywhere"
if dirs=$(printf '%s' "$cmd" | python3 "$(dirname "${BASH_SOURCE[0]}")/lib/git-command.py" --dir "$base" 2>/dev/null); then
  commit_dirs=""
  while IFS= read -r line; do
    dir=${line%%$'\t'*}
    printf '%s\n' "${line#*$'\t'}" | grep -qE "$commit_re" && commit_dirs+="${dir:-$anywhere}"$'\n'
  done <<<"$dirs"
  [ -n "$commit_dirs" ] || commit_dirs="$anywhere"
fi

added=""
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  added+=$(git -C "$dir" diff --cached 2>/dev/null | grep '^+' | grep -v '^+++' || true)$'\n'
done <<<"$commit_dirs"
[ -z "${added//$'\n'/}" ] && exit 0

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
