#!/bin/bash
# Verification harness for sub-task 2 of ship-release-automation:
# the claude-plugin `--apply` case in bump-semver.sh that writes plugin.json
# and marketplace.json atomically.
#
# Usage:
#   bash plugins/forge/skills/ship/scripts/__verify__/test-sub2.sh
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

WORK=$(mktemp -d "/tmp/bump-semver-test-sub2-XXXXXX")
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
# T2.1 — After --apply, plugins/forge/.claude-plugin/plugin.json
#   has its .version bumped to the new version.
# T2.2 — .claude-plugin/marketplace.json has .metadata.version bumped.
# T2.3 — .claude-plugin/marketplace.json plugins[] entry for "forge"
#   has its .version bumped.
#
# Scenario: single-plugin repo at 0.3.0, one feat commit.
# Expected: after --apply, all three fields read "0.4.0".
############################################################
T1=$WORK/t1
init_repo "$T1"
(
  cd "$T1"
  mkdir -p .claude-plugin plugins/forge/.claude-plugin
  cat > .claude-plugin/marketplace.json <<'EOF'
{
  "name": "mp",
  "metadata": { "version": "0.3.0" },
  "plugins": [
    { "name": "forge", "version": "0.3.0" }
  ]
}
EOF
  printf '{"name":"forge","version":"0.3.0"}\n' > plugins/forge/.claude-plugin/plugin.json
  git add .
  git commit -q -m "feat(forge): add plugin manifest"
)
T1_STDOUT=$(cd "$T1" && bash "$SCRIPT" HEAD~1..HEAD --apply 2>/dev/null || true)
T1_PLUGIN_V=$(cd "$T1" && jq -r '.version' plugins/forge/.claude-plugin/plugin.json 2>/dev/null || echo "READFAIL")
T1_MARKET_META_V=$(cd "$T1" && jq -r '.metadata.version' .claude-plugin/marketplace.json 2>/dev/null || echo "READFAIL")
T1_MARKET_PLUGIN_V=$(cd "$T1" && jq -r '.plugins[] | select(.name == "forge") | .version' .claude-plugin/marketplace.json 2>/dev/null || echo "READFAIL")

report "T2.0 script stdout"              "minor 0.3.0 0.4.0 claude-plugin:1" "$T1_STDOUT"
report "T2.1 plugin.json .version"       "0.4.0" "$T1_PLUGIN_V"
report "T2.2 marketplace .metadata.version" "0.4.0" "$T1_MARKET_META_V"
report "T2.3 marketplace plugins[forge].version" "0.4.0" "$T1_MARKET_PLUGIN_V"

############################################################
# T2.4 — Two-plugin repo where only `forge` is in scope.
#   plugins/alpha/.claude-plugin/plugin.json must remain UNCHANGED
#   after --apply. marketplace.json entry for "alpha" must remain UNCHANGED.
############################################################
T2=$WORK/t2
init_repo "$T2"
(
  cd "$T2"
  mkdir -p .claude-plugin plugins/forge/.claude-plugin plugins/alpha/.claude-plugin
  cat > .claude-plugin/marketplace.json <<'EOF'
{
  "name": "mp",
  "metadata": { "version": "1.0.0" },
  "plugins": [
    { "name": "forge", "version": "1.0.0" },
    { "name": "alpha", "version": "2.5.0" }
  ]
}
EOF
  printf '{"name":"forge","version":"1.0.0"}\n' > plugins/forge/.claude-plugin/plugin.json
  printf '{"name":"alpha","version":"2.5.0"}\n' > plugins/alpha/.claude-plugin/plugin.json
  git add .
  git commit -q -m "chore: seed two plugins"
  # Touch only plugins/forge/; commit a feat.
  echo "forge edit" > plugins/forge/src.txt
  git add plugins/forge/src.txt
  git commit -q -m "feat(forge): tweak"
)
T2_STDOUT=$(cd "$T2" && bash "$SCRIPT" HEAD~1..HEAD --apply 2>/dev/null || true)
T2_FORGE_V=$(cd "$T2" && jq -r '.version' plugins/forge/.claude-plugin/plugin.json 2>/dev/null || echo "READFAIL")
T2_ALPHA_V=$(cd "$T2" && jq -r '.version' plugins/alpha/.claude-plugin/plugin.json 2>/dev/null || echo "READFAIL")
T2_MARKET_FORGE_V=$(cd "$T2" && jq -r '.plugins[] | select(.name == "forge") | .version' .claude-plugin/marketplace.json 2>/dev/null || echo "READFAIL")
T2_MARKET_ALPHA_V=$(cd "$T2" && jq -r '.plugins[] | select(.name == "alpha") | .version' .claude-plugin/marketplace.json 2>/dev/null || echo "READFAIL")
T2_MARKET_META_V=$(cd "$T2" && jq -r '.metadata.version' .claude-plugin/marketplace.json 2>/dev/null || echo "READFAIL")

report "T2.4a script stdout"                        "minor 1.0.0 1.1.0 claude-plugin:1" "$T2_STDOUT"
report "T2.4b forge plugin.json bumped"             "1.1.0" "$T2_FORGE_V"
report "T2.4c alpha plugin.json UNCHANGED"          "2.5.0" "$T2_ALPHA_V"
report "T2.4d marketplace forge entry bumped"       "1.1.0" "$T2_MARKET_FORGE_V"
report "T2.4e marketplace alpha entry UNCHANGED"    "2.5.0" "$T2_MARKET_ALPHA_V"
report "T2.4f marketplace metadata.version bumped"  "1.1.0" "$T2_MARKET_META_V"

############################################################
# T2.5 — Idempotency: running --apply a second time when the
#   range now includes a chore(release) commit.
#   Level computes to none, apply block does not run, no writes happen.
#   Output should be "none <current> <current> none".
############################################################
T3=$WORK/t3
init_repo "$T3"
(
  cd "$T3"
  mkdir -p .claude-plugin plugins/forge/.claude-plugin
  cat > .claude-plugin/marketplace.json <<'EOF'
{
  "name": "mp",
  "metadata": { "version": "0.4.0-alpha" },
  "plugins": [
    { "name": "forge", "version": "0.4.0-alpha" }
  ]
}
EOF
  printf '{"name":"forge","version":"0.4.0-alpha"}\n' > plugins/forge/.claude-plugin/plugin.json
  git add .
  git commit -q -m "chore(release): bump to 0.4.0-alpha"
)
# Snapshot contents before --apply to confirm idempotency.
T3_PLUGIN_BEFORE=$(cd "$T3" && sha1sum plugins/forge/.claude-plugin/plugin.json | awk '{print $1}')
T3_MARKET_BEFORE=$(cd "$T3" && sha1sum .claude-plugin/marketplace.json | awk '{print $1}')
T3_STDOUT=$(cd "$T3" && bash "$SCRIPT" HEAD~1..HEAD --apply 2>/dev/null || true)
T3_LEVEL=$(echo "$T3_STDOUT" | awk '{print $1}')
T3_PLUGIN_AFTER=$(cd "$T3" && sha1sum plugins/forge/.claude-plugin/plugin.json | awk '{print $1}')
T3_MARKET_AFTER=$(cd "$T3" && sha1sum .claude-plugin/marketplace.json | awk '{print $1}')

report "T2.5a level on chore(release) is none"         "none" "$T3_LEVEL"
report "T2.5b plugin.json untouched (apply no-op)"     "$T3_PLUGIN_BEFORE" "$T3_PLUGIN_AFTER"
report "T2.5c marketplace.json untouched (apply no-op)" "$T3_MARKET_BEFORE" "$T3_MARKET_AFTER"

echo
echo "Summary: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
