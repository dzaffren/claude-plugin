#!/bin/bash
# Regression test for the "silent no-op when jq is missing" bug.
#
# bump-semver.sh reads/writes JSON version manifests (package.json and the
# Claude-plugin marketplace layout) through `jq`, with each call guarded by
# `2>/dev/null || true`. When `jq` is absent the error is swallowed, the script
# reports `manifest=none`, and /ship Step 3e mistakes a real feature ship for a
# docs-only ship and silently skips the version bump — leaving versions stale.
#
# Desired behavior (asserted here): when a version bump IS required and a
# jq-dependent manifest is present but `jq` is missing, bump-semver must fail
# LOUDLY — a non-zero exit and a jq-related message on stderr — never a silent
# `none`.
#
# This test forces jq-absence with a curated PATH (a temp bin of wrappers for
# the tools bump-semver needs, deliberately excluding jq), so it is meaningful
# whether or not the host has jq installed. It asserts WITHOUT using jq.
#
# Usage:
#   bash plugins/forge/skills/ship/scripts/__verify__/test-jq-missing-guard.sh
# Exit code: 0 — pass; 1 — fail (bug present); 0 with SKIP — environment could
# not build a jq-free PATH.

set -eu

SCRIPTS_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUMP=$SCRIPTS_DIR/bump-semver.sh
if [ ! -f "$BUMP" ]; then
  echo "ERROR: cannot locate bump-semver.sh at $BUMP" >&2
  exit 1
fi

BASH_BIN=$(command -v bash)
WORKDIR=$(mktemp -d "/tmp/forge-jq-guard-$$-XXXXXX")
trap 'rm -rf "$WORKDIR"' EXIT

# --- scratch Claude-plugin repo with a feat commit (no jq needed to build) ---
REPO=$WORKDIR/repo
mkdir -p "$REPO"
(
  cd "$REPO"
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test"
  git config commit.gpgsign false
  echo "# seed" > README.md
  git add README.md
  git commit -q -m "chore: seed"
  mkdir -p .claude-plugin plugins/forge/.claude-plugin
  printf '{"name":"mp","metadata":{"version":"0.3.0"},"plugins":[{"name":"forge","version":"0.3.0"}]}\n' \
    > .claude-plugin/marketplace.json
  printf '{"name":"forge","version":"0.3.0"}\n' > plugins/forge/.claude-plugin/plugin.json
  git add .
  git commit -q -m "feat(forge): add plugin layout"
)

# --- force jq-absence via a curated PATH: wrappers for the tools bump-semver
#     needs, deliberately WITHOUT a jq wrapper, so `command -v jq` fails. ---
BIN=$WORKDIR/bin
mkdir -p "$BIN"
NEEDED="git grep sed awk ls head tail sort mktemp mv basename"
for t in $NEEDED; do
  real=$(command -v "$t" 2>/dev/null || true)
  if [ -z "$real" ]; then
    echo "SKIP: required tool '$t' not found; cannot build a jq-free PATH on this host"
    exit 0
  fi
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$real" > "$BIN/$t"
  chmod +x "$BIN/$t"
done

# --- run bump-semver under the jq-free PATH ---
OUT_FILE=$WORKDIR/out
ERR_FILE=$WORKDIR/err
EXIT=0
( cd "$REPO" && PATH="$BIN" "$BASH_BIN" "$BUMP" HEAD~1..HEAD --apply >"$OUT_FILE" 2>"$ERR_FILE" ) || EXIT=$?
OUT=$(cat "$OUT_FILE")
ERR=$(cat "$ERR_FILE")

# --- assertions (no jq used) ---
FAILED=0
if [ "$EXIT" -eq 0 ]; then
  echo "FAIL: expected a non-zero exit when jq is missing and a plugin manifest is present; got exit 0" >&2
  echo "      stdout: '$OUT'" >&2
  FAILED=1
fi
if ! printf '%s' "$ERR" | grep -qi jq; then
  echo "FAIL: expected a jq-related error on stderr; got: '$ERR'" >&2
  FAILED=1
fi
case "$OUT" in
  *" none")
    echo "FAIL: bump-semver silently reported manifest 'none' instead of failing loudly: '$OUT'" >&2
    FAILED=1
    ;;
esac

if [ "$FAILED" -eq 0 ]; then
  echo "PASS: bump-semver fails loudly when jq is missing and a bump-needing manifest is present"
  exit 0
fi
exit 1
