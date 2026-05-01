#!/bin/bash
# PreToolUse hook — if a git commit is about to run, scan the staged diff for
# high-confidence secret patterns (API keys, private keys, tokens, PATs).
# Block the commit when a match is found unless the pattern or file is
# explicitly allowlisted in .secretscanignore at the repo root.
#
# Allowlist format (one entry per line, '#' starts a comment):
#   pattern:<regex>    — ignore any hit where the full line matches <regex>
#   path:<glob>        — ignore any hit in a file whose path matches <glob>
#                        (glob is evaluated with `git ls-files -- <glob>`)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

if ! echo "$COMMAND" | grep -qEi '(^|;|&&|\|\|)\s*git\s+commit'; then
  exit 0
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
  exit 0
fi

STAGED_DIFF=$(git diff --cached --no-color -U0 2>/dev/null)
if [ -z "$STAGED_DIFF" ]; then
  exit 0
fi

IGNORE_FILE="$REPO_ROOT/.secretscanignore"
IGNORE_PATTERNS=()
IGNORE_PATHS=()
if [ -f "$IGNORE_FILE" ]; then
  while IFS= read -r line; do
    case "$line" in
      ''|\#*) continue ;;
      pattern:*) IGNORE_PATTERNS+=("${line#pattern:}") ;;
      path:*)    IGNORE_PATHS+=("${line#path:}") ;;
    esac
  done < "$IGNORE_FILE"
fi

# High-confidence secret patterns. Keep this list conservative — false positives
# erode trust faster than the occasional miss (full coverage belongs to a
# dedicated scanner in CI).
declare -a RULES=(
  'GitHub personal access token|ghp_[A-Za-z0-9]{36,}'
  'GitHub OAuth token|gho_[A-Za-z0-9]{36,}'
  'GitHub app user token|ghu_[A-Za-z0-9]{36,}'
  'GitHub app server token|ghs_[A-Za-z0-9]{36,}'
  'GitHub refresh token|ghr_[A-Za-z0-9]{36,}'
  'AWS access key|AKIA[0-9A-Z]{16}'
  'AWS secret access key|aws_secret_access_key\s*=\s*[A-Za-z0-9/+=]{40}'
  'Google API key|AIza[0-9A-Za-z_-]{35}'
  'Slack token|xox[aboprs]-[A-Za-z0-9-]{10,}'
  'Stripe secret key|sk_live_[0-9A-Za-z]{24,}'
  'OpenAI key|sk-[A-Za-z0-9]{32,}'
  'Anthropic key|sk-ant-[A-Za-z0-9-]{40,}'
  'Private key block|-----BEGIN (RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----'
  'JWT literal|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
)

FINDINGS=""

# Iterate added lines only (prefix '+' but not '+++ ' header)
while IFS= read -r raw; do
  case "$raw" in
    '+++ '*) continue ;;
    '+'*) line=${raw#+} ;;
    *) continue ;;
  esac

  for rule in "${RULES[@]}"; do
    label="${rule%%|*}"
    pattern="${rule#*|}"
    if echo "$line" | grep -qE -- "$pattern"; then
      # Pattern allowlist check
      skip=0
      for ig in "${IGNORE_PATTERNS[@]}"; do
        if echo "$line" | grep -qE -- "$ig"; then
          skip=1
          break
        fi
      done
      if [ "$skip" -eq 1 ]; then
        continue
      fi
      FINDINGS="${FINDINGS}- ${label}: $(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-120)"$'\n'
    fi
  done
done <<< "$STAGED_DIFF"

# Apply path allowlist — drop findings whose files are all-ignored
if [ -n "$FINDINGS" ] && [ ${#IGNORE_PATHS[@]} -gt 0 ]; then
  FILTERED=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    keep=1
    for glob in "${IGNORE_PATHS[@]}"; do
      matches=$(git -C "$REPO_ROOT" ls-files -- "$glob" 2>/dev/null)
      if [ -n "$matches" ]; then
        for f in $matches; do
          if git -C "$REPO_ROOT" diff --cached --name-only | grep -qx "$f"; then
            keep=0
            break 2
          fi
        done
      fi
    done
    if [ "$keep" -eq 1 ]; then
      FILTERED="${FILTERED}${line}"$'\n'
    fi
  done <<< "$FINDINGS"
  FINDINGS="$FILTERED"
fi

if [ -z "$FINDINGS" ]; then
  exit 0
fi

REASON="secret-scan blocked this commit. Staged diff contains likely secrets:\n${FINDINGS}\nRemove the secret, rotate it if it has been exposed, then retry. If this is a false positive, add an allowlist entry to .secretscanignore (pattern:<regex> or path:<glob>)."
REASON_JSON=$(printf '%s' "$REASON" | jq -Rs .)
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"block","permissionDecisionReason":%s}}\n' "$REASON_JSON"
exit 0
