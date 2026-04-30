#!/bin/bash
set -euo pipefail
CHANGED="$1"

PY_FILES=$(echo "$CHANGED" | grep '\.py$' || true)
if [ -z "$PY_FILES" ]; then
  echo "PASS: No Python files changed."
  exit 0
fi

ERRORS=""

# Format
python -m black $PY_FILES 2>/dev/null || true
python -m ruff check $PY_FILES --fix 2>/dev/null || true

# Lint
LINT=$(python -m ruff check $PY_FILES 2>&1) || true
if [ -n "$LINT" ]; then
  ERRORS="${ERRORS}LINT FAIL: $(echo "$LINT" | head -5)\n"
fi

# Type check
if command -v mypy &>/dev/null; then
  TYPE_OUT=$(python -m mypy $PY_FILES --ignore-missing-imports 2>&1) || true
  if echo "$TYPE_OUT" | grep -q 'error:'; then
    ERRORS="${ERRORS}TYPE FAIL: $(echo "$TYPE_OUT" | grep 'error:' | head -5)\n"
  fi
fi

# Tests
TEST_OUT=$(python -m pytest --tb=short -q 2>&1) || true
if echo "$TEST_OUT" | grep -qE "FAILED|ERROR"; then
  ERRORS="${ERRORS}TEST FAIL: $(echo "$TEST_OUT" | grep -E 'FAILED|ERROR' | head -5)\n"
fi

if [ -n "$ERRORS" ]; then
  echo "FAIL:"
  echo -e "$ERRORS"
  exit 1
else
  echo "PASS: All checks passed."
  exit 0
fi
