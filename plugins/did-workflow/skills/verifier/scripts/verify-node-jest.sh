#!/bin/bash
set -euo pipefail
CHANGED="$1"

TS_FILES=$(echo "$CHANGED" | grep -E '\.(ts|tsx|js|jsx)$' || true)
if [ -z "$TS_FILES" ]; then
  echo "PASS: No TS/JS files changed."
  exit 0
fi

ERRORS=""

# Format (silent — auto-format hook should have already done this)
npx prettier --write $TS_FILES 2>/dev/null || true

# Type check
TYPE_OUT=$(npx tsc --noEmit 2>&1) || true
if echo "$TYPE_OUT" | grep -q 'error TS'; then
  ERRORS="${ERRORS}TYPE FAIL: $(echo "$TYPE_OUT" | grep 'error TS' | head -5)\n"
fi

# Lint
LINT=$(npx eslint $TS_FILES --format compact 2>&1) || true
if echo "$LINT" | grep -qE ' error '; then
  ERRORS="${ERRORS}LINT FAIL: $(echo "$LINT" | grep 'error' | head -5)\n"
fi

# Tests — find corresponding test files
TEST_LIST=""
for F in $TS_FILES; do
  for P in \
    "$(echo "$F" | sed 's/\.ts$/.test.ts/')" \
    "$(echo "$F" | sed 's/\.tsx$/.test.tsx/')" \
    "$(echo "$F" | sed 's|src/\(.*\)\.ts$|src/__tests__/\1.test.ts|')" \
    "$(echo "$F" | sed 's|src/|tests/|' | sed 's/\.ts$/.test.ts/')"; do
    [ -f "$P" ] && TEST_LIST="$TEST_LIST $P"
  done
done

if [ -n "$TEST_LIST" ]; then
  TEST_OUT=$(npx jest $TEST_LIST --no-coverage --forceExit 2>&1) || true
  if echo "$TEST_OUT" | grep -qEi "FAIL|failed"; then
    ERRORS="${ERRORS}TEST FAIL: $(echo "$TEST_OUT" | grep -Ei 'FAIL|●' | head -5)\n"
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
