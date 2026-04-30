#!/bin/bash
# PostToolUse auto-formatter — runs after every file write.
# Auto-detects file type and applies the right formatter.
# Failures are silent (|| true) so a missing formatter never blocks the agent.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  exit 0
fi

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx)
    npx prettier --write "$FILE" 2>/dev/null || true
    npx eslint "$FILE" --fix 2>/dev/null || true
    ;;
  *.py)
    python -m black "$FILE" 2>/dev/null || true
    python -m ruff check "$FILE" --fix 2>/dev/null || true
    ;;
  *.java)
    if command -v google-java-format &>/dev/null; then
      google-java-format --replace "$FILE" 2>/dev/null || true
    fi
    ;;
  *.kt|*.kts)
    if command -v ktlint &>/dev/null; then
      ktlint --format "$FILE" 2>/dev/null || true
    fi
    ;;
  *.json|*.css|*.scss|*.md|*.yaml|*.yml)
    npx prettier --write "$FILE" 2>/dev/null || true
    ;;
esac

exit 0
