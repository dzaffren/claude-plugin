#!/bin/bash
set -euo pipefail

CHANGED=$(git diff --name-only HEAD 2>/dev/null || echo "")
if [ -z "$CHANGED" ]; then
  echo "PASS: No changes detected."
  exit 0
fi

PLUGIN_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
# Use primary stack (head -1) for dispatch; monorepo support can be layered on top
STACK=$(bash "$PLUGIN_DIR/skills/verifier/scripts/detect-stack.sh" | head -1)

case "$STACK" in
  node-jest)
    bash "$PLUGIN_DIR/skills/verifier/scripts/verify-node-jest.sh" "$CHANGED"
    ;;
  node-vitest)
    bash "$PLUGIN_DIR/skills/verifier/scripts/verify-node-vitest.sh" "$CHANGED"
    ;;
  python)
    bash "$PLUGIN_DIR/skills/verifier/scripts/verify-python.sh" "$CHANGED"
    ;;
  java-gradle|java-maven)
    bash "$PLUGIN_DIR/skills/verifier/scripts/verify-java.sh" "$CHANGED" "$STACK"
    ;;
  *)
    echo "WARN: Unknown stack '$STACK'. Skipping stack-specific checks."
    echo "PASS: Basic checks passed (no stack-specific verifier)."
    exit 0
    ;;
esac
