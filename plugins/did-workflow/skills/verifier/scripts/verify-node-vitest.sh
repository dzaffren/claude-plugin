#!/bin/bash
set -euo pipefail
CHANGED="$1"

TS_FILES=$(echo "$CHANGED" | grep -E '\.(ts|tsx|js|jsx)$' || true)
if [ -z "$TS_FILES" ]; then
  echo "PASS: No TS/JS files changed."
  exit 0
fi

ERRORS=""

npx prettier --write $TS_FILES 2>/dev/null || true

TYPE_OUT=$(npx tsc --noEmit 2>&1) || true
if echo "$TYPE_OUT" | grep -q 'error TS'; then
  ERRORS="${ERRORS}TYPE FAIL: $(echo "$TYPE_OUT" | grep 'error TS' | head -5)\n"
fi

LINT=$(npx eslint $TS_FILES --format compact 2>&1) || true
if echo "$LINT" | grep -qE ' error '; then
  ERRORS="${ERRORS}LINT FAIL: $(echo "$LINT" | grep 'error' | head -5)\n"
fi

TEST_LIST=""
for F in $TS_FILES; do
  TEST=$(echo "$F" | sed 's/\.\(ts\|tsx\)$/\.test.\1/')
  [ -f "$TEST" ] && TEST_LIST="$TEST_LIST $TEST"
done

if [ -n "$TEST_LIST" ]; then
  TEST_OUT=$(npx vitest run $TEST_LIST 2>&1) || true
  if echo "$TEST_OUT" | grep -qEi "FAIL"; then
    ERRORS="${ERRORS}TEST FAIL: $(echo "$TEST_OUT" | grep 'FAIL' | head -5)\n"
  fi
fi

if [ -n "$ERRORS" ]; then
  echo "FAIL:"
  echo -e "$ERRORS"
  exit 1
else
  echo "PASS: All checks passed."
  exit 0
fi
