#!/bin/bash
# Detects the project's primary tech stack.
# Outputs one of: node-jest, node-vitest, python, java-gradle, java-maven, unknown
#
# For monorepos with multiple stacks, outputs each on a separate line.
# Callers that want only the primary stack should pipe through: | head -1

STACKS=""

# --- Node/TypeScript ---
if [ -f "package.json" ]; then
  DEPS=$(cat package.json)
  if echo "$DEPS" | grep -q '"vitest"'; then
    STACKS="${STACKS}node-vitest\n"
  elif echo "$DEPS" | grep -q '"jest"'; then
    STACKS="${STACKS}node-jest\n"
  else
    STACKS="${STACKS}node-jest\n"  # default for any Node project
  fi
fi

# --- Python ---
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "Pipfile" ]; then
  STACKS="${STACKS}python\n"
fi

# --- Java/Kotlin ---
if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
  STACKS="${STACKS}java-gradle\n"
elif [ -f "pom.xml" ]; then
  STACKS="${STACKS}java-maven\n"
fi

if [ -z "$STACKS" ]; then
  echo "unknown"
else
  # Print all detected stacks (callers use | head -1 for primary)
  echo -e "$STACKS" | grep -v '^$'
fi
