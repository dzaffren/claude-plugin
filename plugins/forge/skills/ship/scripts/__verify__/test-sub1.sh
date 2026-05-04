#!/bin/bash
# Verification harness for sub-task 1 of ship-release-automation:
# the claude-plugin manifest detection branch in bump-semver.sh.
#
# Usage:
#   bash plugins/forge/skills/ship/scripts/__verify__/test-sub1.sh
#
# Exit code:
#   0 — all scenarios pass
#   1 — at least one scenario failed (details printed to stderr)

set -u

SCRIPT=$(cd "$(dirname "$0")/.." && pwd)/bump-semver.sh

if [ ! -f "$SCRIPT" ]; then
  echo "ERROR: cannot locate bump-semver.sh at $SCRIPT" >&2
  exit 1
fi

WORK=$(mktemp -d "/tmp/bump-semver-test-XXXXXX")
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

report() {
  local name=$1 expected=$2 actual=$3
  if [ "$expected" = "$actual" ]; then
    echo "PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $name"
    echo "      expected: $expected"
    echo "      actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

# Helper: init a fresh git repo with a default branch, a throwaway identity,
# and a single root commit that the caller can diff against.
init_repo() {
  local dir=$1
  mkdir -p "$dir"
  (
    cd "$dir"
    git init -q -b main
    git config user.email "test@example.com"
    git config user.name  "Test"
    git config commit.gpgsign false
    echo "# seed" > README.md
    git add README.md
    git commit -q -m "chore: seed"
  )
}

############################################################
# T1.1 — fresh repo with only plugins/forge/.claude-plugin/plugin.json
#   HEAD~1..HEAD where HEAD~1 is the seed and HEAD is a feat commit.
#   Expected: "minor 0.1.0 0.2.0 claude-plugin:1"
############################################################
T1=$WORK/t1
init_repo "$T1"
(
  cd "$T1"
  mkdir -p .claude-plugin plugins/forge/.claude-plugin
  printf '{"name":"mp","plugins":[]}\n' > .claude-plugin/marketplace.json
  printf '{"name":"forge","version":"0.1.0"}\n' > plugins/forge/.claude-plugin/plugin.json
  git add .
  git commit -q -m "feat(forge): add plugin manifest"
)
T1_OUT=$(cd "$T1" && bash "$SCRIPT" HEAD~1..HEAD 2>/dev/null || true)
report "T1.1 claude-plugin only" "minor 0.1.0 0.2.0 claude-plugin:1" "$T1_OUT"

############################################################
# T1.2 — both package.json and plugins/forge/.claude-plugin/plugin.json.
#   Standard manifest (package.json) must win.
############################################################
T2=$WORK/t2
init_repo "$T2"
(
  cd "$T2"
  mkdir -p plugins/forge/.claude-plugin
  printf '{"name":"root","version":"1.2.3"}\n' > package.json
  printf '{"name":"forge","version":"0.1.0"}\n' > plugins/forge/.claude-plugin/plugin.json
  git add .
  git commit -q -m "feat: first cut"
)
T2_OUT=$(cd "$T2" && bash "$SCRIPT" HEAD~1..HEAD 2>/dev/null || true)
report "T1.2 package.json wins" "minor 1.2.3 1.3.0 package.json" "$T2_OUT"

############################################################
# T1.3 — docs-only range (no bump, no manifest discovery needed).
############################################################
T3=$WORK/t3
init_repo "$T3"
(
  cd "$T3"
  echo "docs body" > NOTES.md
  git add NOTES.md
  git commit -q -m "docs: notes"
)
T3_OUT=$(cd "$T3" && bash "$SCRIPT" HEAD~1..HEAD 2>/dev/null || true)
report "T1.3 docs-only no bump" "none 0.0.0 0.0.0 none" "$T3_OUT"

############################################################
# T1.4 — diff only touches .claude-plugin/marketplace.json.
#   No plugins/<slug>/ paths changed → IN_SCOPE_PLUGINS empty →
#   MANIFEST stays "none".
############################################################
T4=$WORK/t4
init_repo "$T4"
(
  cd "$T4"
  mkdir -p .claude-plugin plugins/forge/.claude-plugin
  printf '{"name":"mp","plugins":[]}\n' > .claude-plugin/marketplace.json
  printf '{"name":"forge","version":"0.1.0"}\n' > plugins/forge/.claude-plugin/plugin.json
  git add .
  git commit -q -m "chore: seed plugin layout"
  # Now modify ONLY the marketplace file.
  printf '{"name":"mp","plugins":["forge"]}\n' > .claude-plugin/marketplace.json
  git add .claude-plugin/marketplace.json
  git commit -q -m "feat: register forge in marketplace"
)
T4_OUT=$(cd "$T4" && bash "$SCRIPT" HEAD~1..HEAD 2>/dev/null || true)
report "T1.4 marketplace-only stays none" "minor 0.0.0 0.1.0 none" "$T4_OUT"

echo
echo "Summary: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
