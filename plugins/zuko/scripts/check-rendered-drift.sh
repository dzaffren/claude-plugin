#!/usr/bin/env bash
# Gate: a preview's rendered styles must come from the design system's tokens.
# Usage: check-rendered-drift.sh <file.html | folder | http://localhost:PORT/path> [...]
# Renders each page in headless Chrome, light then dark, and fails on any
# colour, font size, font family or corner radius that is not a token value.
# Exit 0 pass, 1 drift or nothing to compare against, 2 could not render.
# A run that rendered nothing is never exit 0.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

usage() {
  cat <<'USAGE'
usage: check-rendered-drift.sh <file.html | folder | http://localhost:PORT/path> [...]
Renders each page in light and dark at 1440px, and fails on any colour, font size,
font family or corner radius that is not a design system token value.
Exit 0: pass. Exit 1: drift, or no tokens to compare. Exit 2: could not render.
USAGE
}

case "${1:-}" in
  (-h|--help) usage; exit 0 ;;
esac

# Node 22 or newer. A winget install puts Node on the machine PATH, which a
# shell opened before the install does not see, so try its full path too.
node=""
if command -v node >/dev/null 2>&1; then
  node=node
elif [ -n "${PROGRAMFILES:-}" ] && [ -x "$PROGRAMFILES/nodejs/node.exe" ]; then
  node="$PROGRAMFILES/nodejs/node.exe"
fi
if [ -z "$node" ]; then
  echo "Rendered drift check could not run: Node not found." >&2
  exit 2
fi
version=$("$node" --version 2>/dev/null)
major=${version#v}
major=${major%%.*}
case "$major" in
  (''|*[!0-9]*) echo "Rendered drift check could not run: Node not found." >&2; exit 2 ;;
esac
if [ "$major" -lt 22 ]; then
  echo "Rendered drift check could not run: Node $version is older than 22." >&2
  exit 2
fi

. "$here/lib/token-files.sh"
token_files=$(find_token_files "${CLAUDE_PROJECT_DIR:-$PWD}")
# Windows Node cannot read a /c/... path from an environment variable.
if [ -n "$token_files" ] && command -v cygpath >/dev/null 2>&1; then
  token_files=$(printf '%s\n' "$token_files" | while IFS= read -r f; do cygpath -m "$f"; done)
fi
export ZUKO_TOKEN_FILES="$token_files"

exec "$node" "$here/lib/rendered-drift.mjs" "$@"
