#!/usr/bin/env bash
# PreToolUse[Bash] hook: block destructive git/file commands.
set -uo pipefail

cmd=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null) || exit 0
[ -z "$cmd" ] && exit 0

deny() { echo "$1" >&2; exit 2; }

if printf '%s' "$cmd" | grep -qE 'git push[^;|&]*(--force|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
  deny "Blocked: force push rewrites shared history. Ask the user first."
fi

if printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)[[:space:]]+(/([[:space:]]|$)|/[a-z]+([[:space:]]|$)|~|\.\.)'; then
  deny "Blocked: recursive delete of a top-level or home path."
fi

if printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git commit'; then
  branch=$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" symbolic-ref --short HEAD 2>/dev/null || true)
  case "$branch" in
    main|master) deny "Blocked: committing directly on $branch. Create a branch first." ;;
  esac
fi

exit 0
