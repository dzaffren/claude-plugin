#!/usr/bin/env bash
# PostToolUse[Write|Edit] hook: run the repo's own formatter on the edited file.
# Only formats when the repo actually has the tool configured — never installs.
set -uo pipefail

file=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null) || exit 0
[ -f "$file" ] || exit 0
dir="${CLAUDE_PROJECT_DIR:-$PWD}"

case "$file" in
  *.js|*.jsx|*.ts|*.tsx|*.json|*.css|*.scss|*.md|*.yaml|*.yml)
    if [ -x "$dir/node_modules/.bin/prettier" ]; then
      "$dir/node_modules/.bin/prettier" --write "$file" >/dev/null 2>&1 || true
    fi
    ;;
  *.py)
    if [ -f "$dir/pyproject.toml" ]; then
      if grep -q '\bruff\b' "$dir/pyproject.toml" && command -v ruff >/dev/null 2>&1; then
        ruff format "$file" >/dev/null 2>&1 || true
      elif grep -q '\bblack\b' "$dir/pyproject.toml" && command -v black >/dev/null 2>&1; then
        black -q "$file" >/dev/null 2>&1 || true
      fi
    fi
    ;;
esac
exit 0
