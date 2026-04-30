#!/bin/bash
# PreToolUse hook — if a git commit is about to run and CHANGELOG.md exists
# in the repo but is NOT staged, block the commit with a reminder.
# If CHANGELOG.md doesn't exist in the repo, skip silently.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Only act on git commit commands
if ! echo "$COMMAND" | grep -qEi '(^|;|&&|\|\|)\s*git\s+commit'; then
  exit 0
fi

# Check if CHANGELOG.md exists in the repo (any location)
CHANGELOG=$(git ls-files --full-name '*.md' 2>/dev/null | grep -i 'changelog\.md' | head -1)

if [ -z "$CHANGELOG" ]; then
  # No CHANGELOG.md tracked in repo — skip
  exit 0
fi

# Check if CHANGELOG.md is already staged
if git diff --cached --name-only 2>/dev/null | grep -qi 'changelog\.md'; then
  # Already staged — good to go
  exit 0
fi

# CHANGELOG.md exists but isn't staged — block and remind
echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"block\",\"permissionDecisionReason\":\"CHANGELOG.md exists but is not staged. Update CHANGELOG.md with a summary of this change, then stage it before committing.\"}}"
exit 0
