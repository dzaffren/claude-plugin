#!/bin/bash
# PreToolUse safety gate — blocks dangerous commands before they execute.
# Reads the tool call JSON from stdin (provided by Claude Code hook system).

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Destructive filesystem/DB commands
# Match at word boundary to avoid false positives (e.g. "grep rm -rf" in a test)
if echo "$COMMAND" | grep -qEi '(^|;|&&|\|\|)\s*(rm\s+-rf|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+TABLE|FORMAT\s+[A-Z]:|mkfs)'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Destructive command blocked by org policy."}}'
  exit 0
fi

# Network access — block standalone curl/wget/nc invocations (not grep/echo of those words)
# Disabled: uncomment to re-enable network blocking
# if echo "$COMMAND" | grep -qEi '(^|;|&&|\|\|)\s*(curl|wget|nc|ncat|ssh|scp)\s'; then
#   echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Network access blocked. Agents run in isolated environments."}}'
#   exit 0
# fi

# Secret/credential file access
if echo "$COMMAND" | grep -qEi '(cat|echo|cp|mv|less|more|head|tail|nano|vim)\s.*(\.(env|pem)|credentials|secrets|master\.key|private\.key|api_key)'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Credential/secret access blocked by org policy."}}'
  exit 0
fi

# Database destruction commands
if echo "$COMMAND" | grep -qEi '(db:drop|db:reset|migrate\s+reset|db\s+push\s+--force|dropDatabase|flush\s+--all)'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Database destruction blocked by org policy."}}'
  exit 0
fi

# Package publishing
if echo "$COMMAND" | grep -qEi '(^|;|&&|\|\|)\s*(npm\s+publish|pip\s+upload|twine\s+upload|gradle\s+publish|mvn\s+deploy)\s'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Package publishing blocked. Use CI/CD for releases."}}'
  exit 0
fi

exit 0
