#!/bin/bash
# End-to-end scenario harness for ship-release-automation's bump-semver.sh.
# Exercises the 5 Acceptance Criteria scenarios from the spec against scratch
# repos — no live-repo side effects.
#
# Usage:
#   bash plugins/forge/skills/ship/scripts/__verify__/bump-semver-scenarios.sh
#
# Exit code:
#   0 — all 5 scenarios pass
#   1 — at least one scenario failed (details printed to stderr)

set -eu

SCRIPTS_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUMP=$SCRIPTS_DIR/bump-semver.sh
CHLOG=$SCRIPTS_DIR/update-changelog.sh

if [ ! -f "$BUMP" ]; then
  echo "ERROR: cannot locate bump-semver.sh at $BUMP" >&2
  exit 1
fi
if [ ! -f "$CHLOG" ]; then
  echo "ERROR: cannot locate update-changelog.sh at $CHLOG" >&2
  exit 1
fi

WORKDIR="/tmp/forge-bump-scenarios-$$"
mkdir -p "$WORKDIR"
trap 'rm -rf "$WORKDIR"' EXIT

FAIL_COUNT=0

pass() {
  echo "PASS: $1"
}

fail() {
  local name=$1 reason=$2
  echo "FAIL: $name: $reason" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# init_repo — create a fresh git repo at $1 with a seed commit.
# Matches sub-task 2 test exemplar.
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
# Scenario 1 — Single-plugin happy path.
#
# Plugin + marketplace both at 0.3.0-alpha, plus a feat commit.
# Expected stdout: "minor 0.3.0-alpha 0.4.0 claude-plugin:1".
#
# NOTE: compute_new() strips the pre-release tag on the patch component
# before bumping. "0.3.0-alpha" minor-bumps to "0.4.0" (not "0.4.0-alpha").
# This is documented in __verify__/README.md as a known limitation.
############################################################
S1=$WORKDIR/s1
init_repo "$S1"
(
  cd "$S1"
  mkdir -p .claude-plugin plugins/forge/.claude-plugin
  cat > .claude-plugin/marketplace.json <<'EOF'
{
  "name": "mp",
  "metadata": { "version": "0.3.0-alpha" },
  "plugins": [
    { "name": "forge", "version": "0.3.0-alpha" }
  ]
}
EOF
  printf '{"name":"forge","version":"0.3.0-alpha"}\n' > plugins/forge/.claude-plugin/plugin.json
  # Seed a README with a machine-readable version line so we can assert it
  # gets rewritten on --apply.
  cat > README.md <<'EOF'
# demo

**Current version:** 0.3.0-alpha

Evergreen prose.
EOF
  git add .
  git commit -q -m "feat(forge): initial plugin layout"
)

S1_STDOUT=$(cd "$S1" && bash "$BUMP" HEAD~1..HEAD --apply 2>/dev/null || true)
S1_EXPECTED_STDOUT="minor 0.3.0-alpha 0.4.0 claude-plugin:1"
if [ "$S1_STDOUT" != "$S1_EXPECTED_STDOUT" ]; then
  fail "scenario 1 single-plugin happy path" \
    "stdout mismatch: expected '$S1_EXPECTED_STDOUT', got '$S1_STDOUT'"
else
  S1_PLUGIN_V=$(cd "$S1" && jq -er '.version' plugins/forge/.claude-plugin/plugin.json)
  S1_META_V=$(cd "$S1" && jq -er '.metadata.version' .claude-plugin/marketplace.json)
  S1_PLUGINS0_V=$(cd "$S1" && jq -er '.plugins[0].version' .claude-plugin/marketplace.json)
  if [ "$S1_PLUGIN_V" != "0.4.0" ]; then
    fail "scenario 1 single-plugin happy path" \
      "plugin.json .version expected '0.4.0', got '$S1_PLUGIN_V'"
  elif [ "$S1_META_V" != "0.4.0" ]; then
    fail "scenario 1 single-plugin happy path" \
      "marketplace metadata.version expected '0.4.0', got '$S1_META_V'"
  elif [ "$S1_PLUGINS0_V" != "0.4.0" ]; then
    fail "scenario 1 single-plugin happy path" \
      "marketplace plugins[0].version expected '0.4.0', got '$S1_PLUGINS0_V'"
  else
    S1_README_LINE=$(grep -E '^\*\*Current version:\*\*' "$S1/README.md" | head -n1)
    if [ "$S1_README_LINE" != "**Current version:** 0.4.0" ]; then
      fail "scenario 1 single-plugin happy path" \
        "README.md Current version line expected '**Current version:** 0.4.0', got '$S1_README_LINE'"
    else
      pass "scenario 1 single-plugin happy path"
    fi
  fi
fi

############################################################
# Scenario 2 — Docs-only range.
#
# A Claude-plugin repo with a docs-only commit range.
# Expected stdout: "none 0.0.0 0.0.0 none", no writes.
############################################################
S2=$WORKDIR/s2
init_repo "$S2"
(
  cd "$S2"
  mkdir -p .claude-plugin plugins/forge/.claude-plugin
  printf '{"name":"mp","metadata":{"version":"0.3.0"},"plugins":[{"name":"forge","version":"0.3.0"}]}\n' \
    > .claude-plugin/marketplace.json
  printf '{"name":"forge","version":"0.3.0"}\n' > plugins/forge/.claude-plugin/plugin.json
  git add .
  git commit -q -m "chore: seed plugin layout"
  echo "new notes" > NOTES.md
  git add NOTES.md
  git commit -q -m "docs: add notes"
)
S2_PLUGIN_BEFORE=$(cd "$S2" && sha1sum plugins/forge/.claude-plugin/plugin.json | awk '{print $1}')
S2_MARKET_BEFORE=$(cd "$S2" && sha1sum .claude-plugin/marketplace.json | awk '{print $1}')
S2_STDOUT=$(cd "$S2" && bash "$BUMP" HEAD~1..HEAD --apply 2>/dev/null || true)
S2_PLUGIN_AFTER=$(cd "$S2" && sha1sum plugins/forge/.claude-plugin/plugin.json | awk '{print $1}')
S2_MARKET_AFTER=$(cd "$S2" && sha1sum .claude-plugin/marketplace.json | awk '{print $1}')
S2_EXPECTED_STDOUT="none 0.0.0 0.0.0 none"
if [ "$S2_STDOUT" != "$S2_EXPECTED_STDOUT" ]; then
  fail "scenario 2 docs-only range" \
    "stdout mismatch: expected '$S2_EXPECTED_STDOUT', got '$S2_STDOUT'"
elif [ "$S2_PLUGIN_BEFORE" != "$S2_PLUGIN_AFTER" ]; then
  fail "scenario 2 docs-only range" "plugin.json was modified on a no-op run"
elif [ "$S2_MARKET_BEFORE" != "$S2_MARKET_AFTER" ]; then
  fail "scenario 2 docs-only range" "marketplace.json was modified on a no-op run"
else
  pass "scenario 2 docs-only range"
fi

############################################################
# Scenario 3 — Multi-plugin repo where both plugins share a version,
# only one plugin changed.
#
# forge at 1.0.0, alpha at 1.0.0, metadata.version at 1.0.0.
# Diff only touches plugins/forge/. After apply:
#   - forge bumped to 1.1.0
#   - alpha byte-identical (unchanged, at 1.0.0)
#   - marketplace forge entry bumped to 1.1.0, alpha entry unchanged
#   - marketplace metadata.version bumped to 1.1.0 (new highest across all)
#
# Scenario 6 covers the complementary case where alpha is at a higher
# version than forge and metadata.version must NOT regress.
############################################################
S3=$WORKDIR/s3
init_repo "$S3"
(
  cd "$S3"
  mkdir -p .claude-plugin plugins/forge/.claude-plugin plugins/alpha/.claude-plugin
  cat > .claude-plugin/marketplace.json <<'EOF'
{
  "name": "mp",
  "metadata": { "version": "1.0.0" },
  "plugins": [
    { "name": "forge", "version": "1.0.0" },
    { "name": "alpha", "version": "1.0.0" }
  ]
}
EOF
  printf '{"name":"forge","version":"1.0.0"}\n' > plugins/forge/.claude-plugin/plugin.json
  printf '{"name":"alpha","version":"1.0.0"}\n' > plugins/alpha/.claude-plugin/plugin.json
  git add .
  git commit -q -m "chore: seed two plugins"
  echo "forge edit" > plugins/forge/src.txt
  git add plugins/forge/src.txt
  git commit -q -m "feat(forge): tweak"
)
S3_ALPHA_BEFORE=$(cd "$S3" && sha1sum plugins/alpha/.claude-plugin/plugin.json | awk '{print $1}')
S3_STDOUT=$(cd "$S3" && bash "$BUMP" HEAD~1..HEAD --apply 2>/dev/null || true)
S3_ALPHA_AFTER=$(cd "$S3" && sha1sum plugins/alpha/.claude-plugin/plugin.json | awk '{print $1}')
S3_EXPECTED_STDOUT="minor 1.0.0 1.1.0 claude-plugin:1"
S3_FORGE_V=$(cd "$S3" && jq -er '.version' plugins/forge/.claude-plugin/plugin.json 2>/dev/null || echo READFAIL)
S3_MARKET_FORGE_V=$(cd "$S3" && jq -er '.plugins[] | select(.name=="forge") | .version' .claude-plugin/marketplace.json 2>/dev/null || echo READFAIL)
S3_MARKET_ALPHA_V=$(cd "$S3" && jq -er '.plugins[] | select(.name=="alpha") | .version' .claude-plugin/marketplace.json 2>/dev/null || echo READFAIL)
S3_MARKET_META_V=$(cd "$S3" && jq -er '.metadata.version' .claude-plugin/marketplace.json 2>/dev/null || echo READFAIL)

if [ "$S3_STDOUT" != "$S3_EXPECTED_STDOUT" ]; then
  fail "scenario 3 multi-plugin one changed" \
    "stdout mismatch: expected '$S3_EXPECTED_STDOUT', got '$S3_STDOUT'"
elif [ "$S3_FORGE_V" != "1.1.0" ]; then
  fail "scenario 3 multi-plugin one changed" \
    "forge plugin.json .version expected '1.1.0', got '$S3_FORGE_V'"
elif [ "$S3_ALPHA_BEFORE" != "$S3_ALPHA_AFTER" ]; then
  fail "scenario 3 multi-plugin one changed" \
    "alpha plugin.json was modified (expected byte-identical)"
elif [ "$S3_MARKET_FORGE_V" != "1.1.0" ]; then
  fail "scenario 3 multi-plugin one changed" \
    "marketplace forge entry expected '1.1.0', got '$S3_MARKET_FORGE_V'"
elif [ "$S3_MARKET_ALPHA_V" != "1.0.0" ]; then
  fail "scenario 3 multi-plugin one changed" \
    "marketplace alpha entry expected unchanged '1.0.0', got '$S3_MARKET_ALPHA_V'"
elif [ "$S3_MARKET_META_V" != "1.1.0" ]; then
  fail "scenario 3 multi-plugin one changed" \
    "marketplace metadata.version expected '1.1.0', got '$S3_MARKET_META_V'"
else
  pass "scenario 3 multi-plugin one changed"
fi

############################################################
# Scenario 4 — Standard package.json repo, no Claude-plugin manifests.
#
# Tests backwards compatibility: the Claude-plugin branch must NOT fire
# when a standard manifest is present.
#
# Expected stdout: "minor 1.4.2 1.5.0 package.json".
# Expected state: package.json .version = "1.5.0".
############################################################
S4=$WORKDIR/s4
init_repo "$S4"
(
  cd "$S4"
  printf '{"name":"demo","version":"1.4.2"}\n' > package.json
  # Seed README with version line to confirm the rewrite also fires on the
  # standard-manifest --apply path (not just the claude-plugin:* branch).
  cat > README.md <<'EOF'
# demo

**Current version:** 1.4.2
EOF
  git add package.json README.md
  git commit -q -m "feat: ship demo"
)
S4_STDOUT=$(cd "$S4" && bash "$BUMP" HEAD~1..HEAD --apply 2>/dev/null || true)
S4_EXPECTED_STDOUT="minor 1.4.2 1.5.0 package.json"
S4_PKG_V=$(cd "$S4" && jq -er '.version' package.json 2>/dev/null || echo READFAIL)

if [ "$S4_STDOUT" != "$S4_EXPECTED_STDOUT" ]; then
  fail "scenario 4 package.json backwards-compat" \
    "stdout mismatch: expected '$S4_EXPECTED_STDOUT', got '$S4_STDOUT'"
elif [ "$S4_PKG_V" != "1.5.0" ]; then
  fail "scenario 4 package.json backwards-compat" \
    "package.json .version expected '1.5.0', got '$S4_PKG_V'"
else
  S4_README_LINE=$(grep -E '^\*\*Current version:\*\*' "$S4/README.md" | head -n1)
  if [ "$S4_README_LINE" != "**Current version:** 1.5.0" ]; then
    fail "scenario 4 package.json backwards-compat" \
      "README.md Current version line expected '**Current version:** 1.5.0', got '$S4_README_LINE'"
  else
    pass "scenario 4 package.json backwards-compat"
  fi
fi

############################################################
# Scenario 5 — Claude-plugin repo + missing CHANGELOG.md.
#
# End-to-end chain: bump-semver.sh succeeds; then invoke
# update-changelog.sh --release <new> from the same cwd. It should print
# "no CHANGELOG.md in cwd; skipping" on stderr and exit 0. The overall
# scenario exits 0.
############################################################
S5=$WORKDIR/s5
init_repo "$S5"
(
  cd "$S5"
  mkdir -p .claude-plugin plugins/forge/.claude-plugin
  printf '{"name":"mp","metadata":{"version":"0.3.0"},"plugins":[{"name":"forge","version":"0.3.0"}]}\n' \
    > .claude-plugin/marketplace.json
  printf '{"name":"forge","version":"0.3.0"}\n' > plugins/forge/.claude-plugin/plugin.json
  git add .
  git commit -q -m "feat(forge): release-ready plugin"
)
S5_BUMP_STDOUT=$(cd "$S5" && bash "$BUMP" HEAD~1..HEAD --apply 2>/dev/null || true)
S5_BUMP_EXPECTED="minor 0.3.0 0.4.0 claude-plugin:1"
if [ "$S5_BUMP_STDOUT" != "$S5_BUMP_EXPECTED" ]; then
  fail "scenario 5 missing CHANGELOG.md end-to-end" \
    "bump-semver.sh stdout expected '$S5_BUMP_EXPECTED', got '$S5_BUMP_STDOUT'"
else
  # Now call update-changelog.sh --release 0.4.0 from the same cwd.
  # It must: print the skip notice on stderr, exit 0, write nothing.
  S5_CHLOG_STDERR_FILE=$WORKDIR/s5-chlog-stderr
  S5_CHLOG_EXIT=0
  (cd "$S5" && bash "$CHLOG" --release 0.4.0 2>"$S5_CHLOG_STDERR_FILE") || S5_CHLOG_EXIT=$?
  S5_CHLOG_STDERR=$(cat "$S5_CHLOG_STDERR_FILE" 2>/dev/null || true)
  if [ "$S5_CHLOG_EXIT" -ne 0 ]; then
    fail "scenario 5 missing CHANGELOG.md end-to-end" \
      "update-changelog.sh --release exited $S5_CHLOG_EXIT, expected 0"
  elif [ "$S5_CHLOG_STDERR" != "no CHANGELOG.md in cwd; skipping" ]; then
    fail "scenario 5 missing CHANGELOG.md end-to-end" \
      "stderr expected 'no CHANGELOG.md in cwd; skipping', got '$S5_CHLOG_STDERR'"
  elif [ -f "$S5/CHANGELOG.md" ]; then
    fail "scenario 5 missing CHANGELOG.md end-to-end" \
      "CHANGELOG.md was created (expected no-op)"
  else
    pass "scenario 5 missing CHANGELOG.md end-to-end"
  fi
fi

############################################################
# Scenario 6 — Multi-plugin: metadata.version must NOT regress.
#
# Marketplace tracks metadata.version=2.5.0 because alpha is at 2.5.0,
# higher than forge at 1.0.0. A feat commit is scoped only to forge.
# After apply:
#   - forge bumped to 1.1.0
#   - alpha byte-identical at 2.5.0
#   - marketplace plugins[forge] = 1.1.0, plugins[alpha] = 2.5.0 (unchanged)
#   - marketplace metadata.version STAYS at 2.5.0 (NOT regressed to 1.1.0)
#
# Regression guard for the deferred PR #6 code-reviewer finding.
############################################################
S6=$WORKDIR/s6
init_repo "$S6"
(
  cd "$S6"
  mkdir -p .claude-plugin plugins/forge/.claude-plugin plugins/alpha/.claude-plugin
  cat > .claude-plugin/marketplace.json <<'EOF'
{
  "name": "mp",
  "metadata": { "version": "2.5.0" },
  "plugins": [
    { "name": "forge", "version": "1.0.0" },
    { "name": "alpha", "version": "2.5.0" }
  ]
}
EOF
  printf '{"name":"forge","version":"1.0.0"}\n' > plugins/forge/.claude-plugin/plugin.json
  printf '{"name":"alpha","version":"2.5.0"}\n' > plugins/alpha/.claude-plugin/plugin.json
  git add .
  git commit -q -m "chore: seed two plugins at differing versions"
  echo "forge edit" > plugins/forge/src.txt
  git add plugins/forge/src.txt
  git commit -q -m "feat(forge): tweak"
)
S6_ALPHA_BEFORE=$(cd "$S6" && sha1sum plugins/alpha/.claude-plugin/plugin.json | awk '{print $1}')
S6_STDOUT=$(cd "$S6" && bash "$BUMP" HEAD~1..HEAD --apply 2>/dev/null || true)
S6_ALPHA_AFTER=$(cd "$S6" && sha1sum plugins/alpha/.claude-plugin/plugin.json | awk '{print $1}')
S6_EXPECTED_STDOUT="minor 1.0.0 1.1.0 claude-plugin:1"
S6_FORGE_V=$(cd "$S6" && jq -er '.version' plugins/forge/.claude-plugin/plugin.json 2>/dev/null || echo READFAIL)
S6_MARKET_FORGE_V=$(cd "$S6" && jq -er '.plugins[] | select(.name=="forge") | .version' .claude-plugin/marketplace.json 2>/dev/null || echo READFAIL)
S6_MARKET_ALPHA_V=$(cd "$S6" && jq -er '.plugins[] | select(.name=="alpha") | .version' .claude-plugin/marketplace.json 2>/dev/null || echo READFAIL)
S6_MARKET_META_V=$(cd "$S6" && jq -er '.metadata.version' .claude-plugin/marketplace.json 2>/dev/null || echo READFAIL)

if [ "$S6_STDOUT" != "$S6_EXPECTED_STDOUT" ]; then
  fail "scenario 6 metadata.version regression guard" \
    "stdout mismatch: expected '$S6_EXPECTED_STDOUT', got '$S6_STDOUT'"
elif [ "$S6_FORGE_V" != "1.1.0" ]; then
  fail "scenario 6 metadata.version regression guard" \
    "forge plugin.json .version expected '1.1.0', got '$S6_FORGE_V'"
elif [ "$S6_ALPHA_BEFORE" != "$S6_ALPHA_AFTER" ]; then
  fail "scenario 6 metadata.version regression guard" \
    "alpha plugin.json was modified (expected byte-identical)"
elif [ "$S6_MARKET_FORGE_V" != "1.1.0" ]; then
  fail "scenario 6 metadata.version regression guard" \
    "marketplace forge entry expected '1.1.0', got '$S6_MARKET_FORGE_V'"
elif [ "$S6_MARKET_ALPHA_V" != "2.5.0" ]; then
  fail "scenario 6 metadata.version regression guard" \
    "marketplace alpha entry expected unchanged '2.5.0', got '$S6_MARKET_ALPHA_V'"
elif [ "$S6_MARKET_META_V" != "2.5.0" ]; then
  fail "scenario 6 metadata.version regression guard" \
    "marketplace metadata.version REGRESSED: expected '2.5.0' (still — highest of out-of-scope alpha), got '$S6_MARKET_META_V'"
else
  pass "scenario 6 metadata.version regression guard"
fi

############################################################
# Scenario 7 — Multi-plugin: SemVer pre-release ordering.
#
# alpha (out of scope) sits at 2.0.0-beta — pre-release. forge at 1.0.0
# gets a feat bump. `sort -V` alone would rank "2.0.0-beta" higher than
# any clean release, which contradicts SemVer 2.0.0 (pre-release < release).
#
# Expected behavior: metadata.version = highest CLEAN release across
# plugins[], which is 1.1.0 (the newly bumped forge). The pre-release
# alpha is treated as "in flight" and does NOT drive metadata.version.
# alpha's own plugin.json stays byte-identical.
############################################################
S7=$WORKDIR/s7
init_repo "$S7"
(
  cd "$S7"
  mkdir -p .claude-plugin plugins/forge/.claude-plugin plugins/alpha/.claude-plugin
  cat > .claude-plugin/marketplace.json <<'EOF'
{
  "name": "mp",
  "metadata": { "version": "1.0.0" },
  "plugins": [
    { "name": "forge", "version": "1.0.0" },
    { "name": "alpha", "version": "2.0.0-beta" }
  ]
}
EOF
  printf '{"name":"forge","version":"1.0.0"}\n' > plugins/forge/.claude-plugin/plugin.json
  printf '{"name":"alpha","version":"2.0.0-beta"}\n' > plugins/alpha/.claude-plugin/plugin.json
  git add .
  git commit -q -m "chore: seed two plugins, alpha on a pre-release"
  echo "forge edit" > plugins/forge/src.txt
  git add plugins/forge/src.txt
  git commit -q -m "feat(forge): tweak"
)
S7_ALPHA_BEFORE=$(cd "$S7" && sha1sum plugins/alpha/.claude-plugin/plugin.json | awk '{print $1}')
S7_STDOUT=$(cd "$S7" && bash "$BUMP" HEAD~1..HEAD --apply 2>/dev/null || true)
S7_ALPHA_AFTER=$(cd "$S7" && sha1sum plugins/alpha/.claude-plugin/plugin.json | awk '{print $1}')
S7_EXPECTED_STDOUT="minor 1.0.0 1.1.0 claude-plugin:1"
S7_FORGE_V=$(cd "$S7" && jq -er '.version' plugins/forge/.claude-plugin/plugin.json 2>/dev/null || echo READFAIL)
S7_MARKET_ALPHA_V=$(cd "$S7" && jq -er '.plugins[] | select(.name=="alpha") | .version' .claude-plugin/marketplace.json 2>/dev/null || echo READFAIL)
S7_MARKET_META_V=$(cd "$S7" && jq -er '.metadata.version' .claude-plugin/marketplace.json 2>/dev/null || echo READFAIL)

if [ "$S7_STDOUT" != "$S7_EXPECTED_STDOUT" ]; then
  fail "scenario 7 pre-release sibling" \
    "stdout mismatch: expected '$S7_EXPECTED_STDOUT', got '$S7_STDOUT'"
elif [ "$S7_FORGE_V" != "1.1.0" ]; then
  fail "scenario 7 pre-release sibling" \
    "forge plugin.json .version expected '1.1.0', got '$S7_FORGE_V'"
elif [ "$S7_ALPHA_BEFORE" != "$S7_ALPHA_AFTER" ]; then
  fail "scenario 7 pre-release sibling" \
    "alpha plugin.json was modified (expected byte-identical)"
elif [ "$S7_MARKET_ALPHA_V" != "2.0.0-beta" ]; then
  fail "scenario 7 pre-release sibling" \
    "marketplace alpha entry expected unchanged '2.0.0-beta', got '$S7_MARKET_ALPHA_V'"
elif [ "$S7_MARKET_META_V" != "1.1.0" ]; then
  fail "scenario 7 pre-release sibling" \
    "metadata.version must track highest CLEAN release (1.1.0), not pre-release '2.0.0-beta'; got '$S7_MARKET_META_V'"
else
  pass "scenario 7 pre-release sibling"
fi

PASS_COUNT=$((7 - FAIL_COUNT))
echo
echo "$PASS_COUNT/7 scenarios passed"
[ "$FAIL_COUNT" -eq 0 ]
