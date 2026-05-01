#!/bin/bash
# Validate a commit message against the strict conventional-commit subject
# line rules described in references/commit-conventions.md.
#
# Usage:
#   conventional-commit.sh <message-file>
#   printf '%s\n' "feat(auth): add login" | conventional-commit.sh -
#
# Exit codes:
#   0 — valid
#   1 — invalid (reason printed to stderr)

set -eu

SRC=${1:-}
if [ -z "$SRC" ]; then
  echo "usage: $(basename "$0") <message-file|->" >&2
  exit 2
fi

if [ "$SRC" = "-" ]; then
  MSG=$(cat)
else
  MSG=$(cat "$SRC")
fi

SUBJECT=$(printf '%s' "$MSG" | head -n1)

if [ -z "$SUBJECT" ]; then
  echo "invalid: subject line is empty" >&2
  exit 1
fi

TYPES='feat|fix|refactor|perf|docs|test|chore|build|ci|style|revert'

if ! printf '%s' "$SUBJECT" | grep -qE "^(${TYPES})(\([a-z0-9._-]+\))?!?: [^ ].*"; then
  echo "invalid: subject must match 'type(scope)?: description' with type in {${TYPES}}" >&2
  echo "got: ${SUBJECT}" >&2
  exit 1
fi

if [ "${#SUBJECT}" -gt 72 ]; then
  echo "invalid: subject exceeds 72 characters (${#SUBJECT})" >&2
  exit 1
fi

DESC=$(printf '%s' "$SUBJECT" | sed -E "s/^(${TYPES})(\([a-z0-9._-]+\))?!?: //")

if printf '%s' "$DESC" | grep -qE '\.$'; then
  echo "invalid: subject must not end with a period" >&2
  exit 1
fi

FIRST=$(printf '%s' "$DESC" | cut -c1)
if printf '%s' "$FIRST" | grep -qE '[A-Z]'; then
  echo "invalid: description must be lowercase (got leading '${FIRST}')" >&2
  exit 1
fi

if printf '%s' "$DESC" | grep -qiE '^(added|fixed|fixes|updated|changed|refactored|removed|adding|fixing) '; then
  echo "invalid: description must use imperative mood (e.g. 'add' not 'added')" >&2
  exit 1
fi

# Co-author trailer is explicitly forbidden by forge's ship philosophy.
if printf '%s' "$MSG" | grep -qiE '^Co-Authored-By:'; then
  echo "invalid: Co-Authored-By trailer is not allowed in forge commits" >&2
  exit 1
fi

exit 0
