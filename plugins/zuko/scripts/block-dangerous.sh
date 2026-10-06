#!/usr/bin/env bash
# PreToolUse[Bash] hook: block destructive git/file commands.
set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null) || { printf '%s\n' "Blocked: could not read the hook payload, so this command was not checked." "Run it again without unusual characters." >&2; exit 2; }
[ -z "$cmd" ] && exit 0

# Where the command starts: the hook's cwd, which follows the session's cd.
base=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)
project="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -n "$base" ] || base="$project"

deny() { echo "$1" >&2; exit 2; }

# What git is actually being asked to do, one invocation per line, so a command
# that only mentions "git commit" in a quoted argument or a heredoc body is not
# mistaken for one. A parse failure falls back to matching the raw text, which
# over-blocks rather than under-blocks.
git_args=$(printf '%s' "$cmd" | python3 "$(dirname "${BASH_SOURCE[0]}")/lib/git-command.py" 2>/dev/null)
if [ $? -eq 0 ]; then
  subject="$git_args"
  push_re='^push( .*)? (--force[^[:space:]]*|-f)([[:space:]]|$)'
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

# release-ok: the commit's own directory is known, so it may be the release
# commit release.py cut prepared, the one commit allowed on main (D30).
deny_commit_on_main() {   # deny_commit_on_main <dir> [release-ok]
  local branch out
  branch=$(git -C "$1" symbolic-ref --short HEAD 2>/dev/null || true)
  case "$branch" in
    main|master)
      if [ "${2:-}" = release-ok ]; then
        out=$(printf '%s' "$cmd" | python3 "$(dirname "${BASH_SOURCE[0]}")/lib/release-commit.py" "$1" 2>/dev/null)
        case $? in
          0) return 0 ;;
          1) deny "Blocked: committing directly on $branch. $out" ;;
          4) ;;
          *) deny "Blocked: committing directly on $branch. A release commit needs the marker
release.py cut writes; run /release." ;;
        esac
      fi
      deny "Blocked: committing directly on $branch. Create a branch first." ;;
  esac
}

# A commit lands on the branch of the directory it runs in: the start moved by
# a cd before it and by git's -C. A directory the parser cannot know comes back
# empty, and then both the start and the project dir are checked, as they are
# for every commit in a command that will not parse — never looser than
# checking the project dir alone.
deny_commit_anywhere() {
  deny_commit_on_main "$base"
  deny_commit_on_main "$project"
}

if printf '%s\n' "$subject" | grep -qE "$commit_re"; then
  if dirs=$(printf '%s' "$cmd" | python3 "$(dirname "${BASH_SOURCE[0]}")/lib/git-command.py" --dir "$base" 2>/dev/null); then
    # Split on the first tab by hand: read with IFS=tab strips a leading one,
    # and an empty directory would shift the arguments into it.
    while IFS= read -r line; do
      dir=${line%%$'\t'*}
      printf '%s\n' "${line#*$'\t'}" | grep -qE "$commit_re" || continue
      if [ -n "$dir" ]; then deny_commit_on_main "$dir" release-ok; else deny_commit_anywhere; fi
    done <<<"$dirs"
  else
    deny_commit_anywhere
  fi
fi

exit 0
