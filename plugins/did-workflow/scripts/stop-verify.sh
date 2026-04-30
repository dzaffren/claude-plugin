#!/bin/bash
# Stop hook — runs when the agent finishes a task.
# Delegates to the verifier skill. 2-round retry cap.

INPUT=$(cat)
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# Avoid infinite loop: if we're already in a stop-triggered re-run, exit
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

RETRY_FILE="/tmp/claude-verify-${CLAUDE_SESSION_ID:-default}"
COUNT=$(cat "$RETRY_FILE" 2>/dev/null || echo 0)

if [ "$COUNT" -ge 2 ]; then
  echo "Verification cap reached (2 rounds). Flagging for human review." >&2
  rm -f "$RETRY_FILE"
  exit 0
fi

CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null)
if [ -z "$CHANGED_FILES" ]; then
  rm -f "$RETRY_FILE"
  exit 0
fi

echo $((COUNT + 1)) > "$RETRY_FILE"

# Delegate to the verifier skill's verify.sh
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULT=$(bash "$PLUGIN_DIR/skills/verifier/scripts/verify.sh" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || echo "$RESULT" | grep -q "^FAIL"; then
  ERRORS=$(echo "$RESULT" | grep -v "^PASS" | head -10 | tr '\n' ' ')
  echo "{\"decision\":\"block\",\"reason\":\"Verification failed (round $((COUNT + 1))/2): $ERRORS\"}"
else
  rm -f "$RETRY_FILE"
fi

exit 0
