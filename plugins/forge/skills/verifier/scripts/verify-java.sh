#!/bin/bash
set -euo pipefail
CHANGED="$1"
BUILD_SYSTEM="${2:-java-gradle}"

JAVA_FILES=$(echo "$CHANGED" | grep -E '\.(java|kt)$' || true)
if [ -z "$JAVA_FILES" ]; then
  echo "PASS: No Java/Kotlin files changed."
  exit 0
fi

ERRORS=""

if [ "$BUILD_SYSTEM" = "java-gradle" ]; then
  if [ -f "./gradlew" ]; then
    BUILD_OUT=$(./gradlew check --no-daemon -q 2>&1) || true
  else
    BUILD_OUT=$(gradle check --no-daemon -q 2>&1) || true
  fi
  if echo "$BUILD_OUT" | grep -qEi "FAIL|error"; then
    ERRORS="${ERRORS}GRADLE FAIL: $(echo "$BUILD_OUT" | grep -Ei 'FAIL|error' | head -5)\n"
  fi
elif [ "$BUILD_SYSTEM" = "java-maven" ]; then
  BUILD_OUT=$(mvn verify -q 2>&1) || true
  if echo "$BUILD_OUT" | grep -qEi "FAIL|ERROR"; then
    ERRORS="${ERRORS}MAVEN FAIL: $(echo "$BUILD_OUT" | grep -Ei 'FAIL|ERROR' | head -5)\n"
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
