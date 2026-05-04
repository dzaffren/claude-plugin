#!/bin/bash
# Derive the semver bump required for a range of commits and (optionally) apply
# it to the project's version file.
#
# Usage:
#   bump-semver.sh <range> [--apply]
#     <range>   — git commit range (e.g. origin/main..HEAD or HEAD~3..HEAD)
#     --apply   — write the new version to the detected manifest.
#                 Without this flag the script only prints the computed bump.
#
# Output (stdout, always):
#   <level> <old-version> <new-version> <manifest-path-or-"none">
#
# Bump rules (highest wins):
#   BREAKING CHANGE footer / "!" marker  → major
#   feat                                 → minor
#   fix | refactor | perf                → patch
#   docs | test | chore | ci | style | build | revert — no bump
#
# Supported manifests (first match wins):
#   package.json, pyproject.toml, Cargo.toml, *.csproj, *.gemspec

set -eu

RANGE=${1:-}
APPLY=0
if [ "${2:-}" = "--apply" ]; then
  APPLY=1
fi

if [ -z "$RANGE" ]; then
  echo "usage: $(basename "$0") <range> [--apply]" >&2
  exit 2
fi

LOG=$(git log --format='%B%n---FORGE-END---' "$RANGE" 2>/dev/null || true)
if [ -z "$LOG" ]; then
  echo "none 0.0.0 0.0.0 none"
  exit 0
fi

LEVEL=none
while IFS= read -r line; do
  [ "$line" = "---FORGE-END---" ] && continue
  case "$line" in
    *"BREAKING CHANGE"*|*"BREAKING-CHANGE"*)
      LEVEL=major
      break
      ;;
  esac
done <<< "$LOG"

if [ "$LEVEL" != "major" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    subject_match=0
    case "$line" in
      feat*!:*|fix*!:*|refactor*!:*|perf*!:*|chore*!:*|docs*!:*|build*!:*|ci*!:*|style*!:*|test*!:*|revert*!:*)
        LEVEL=major
        break
        ;;
    esac
    case "$line" in
      feat:*|feat\(*\):*)
        [ "$LEVEL" = "none" ] || [ "$LEVEL" = "patch" ] && LEVEL=minor
        subject_match=1
        ;;
      fix:*|fix\(*\):*|refactor:*|refactor\(*\):*|perf:*|perf\(*\):*)
        [ "$LEVEL" = "none" ] && LEVEL=patch
        subject_match=1
        ;;
    esac
  done <<< "$LOG"
fi

# Locate manifest + read current version
MANIFEST=none
OLD=0.0.0

if [ -f "package.json" ]; then
  V=$(jq -r '.version // empty' package.json 2>/dev/null || true)
  if [ -n "$V" ]; then
    MANIFEST=package.json
    OLD="$V"
  fi
fi

if [ "$MANIFEST" = "none" ] && [ -f "pyproject.toml" ]; then
  V=$(grep -E '^version\s*=' pyproject.toml | head -n1 | sed -E 's/^version\s*=\s*"?([^"]+)"?\s*$/\1/')
  if [ -n "$V" ]; then
    MANIFEST=pyproject.toml
    OLD="$V"
  fi
fi

if [ "$MANIFEST" = "none" ] && [ -f "Cargo.toml" ]; then
  V=$(awk '/^\[package\]/{p=1;next} /^\[/{p=0} p && /^version\s*=/{gsub(/[" ]/,""); sub(/^version=/,""); print; exit}' Cargo.toml)
  if [ -n "$V" ]; then
    MANIFEST=Cargo.toml
    OLD="$V"
  fi
fi

if [ "$MANIFEST" = "none" ]; then
  CSPROJ=$(ls -1 *.csproj 2>/dev/null | head -n1 || true)
  if [ -n "$CSPROJ" ]; then
    V=$(grep -oE '<Version>[^<]+</Version>' "$CSPROJ" | head -n1 | sed -E 's|</?Version>||g')
    if [ -n "$V" ]; then
      MANIFEST="$CSPROJ"
      OLD="$V"
    fi
  fi
fi

if [ "$MANIFEST" = "none" ]; then
  GEMSPEC=$(ls -1 *.gemspec 2>/dev/null | head -n1 || true)
  if [ -n "$GEMSPEC" ]; then
    V=$(grep -oE "version\s*=\s*[\"'][^\"']+[\"']" "$GEMSPEC" | head -n1 | sed -E "s/version\s*=\s*[\"']([^\"']+)[\"']/\1/")
    if [ -n "$V" ]; then
      MANIFEST="$GEMSPEC"
      OLD="$V"
    fi
  fi
fi

# Claude-plugin marketplace layout: no top-level manifest, but one or more
# plugins/<slug>/.claude-plugin/plugin.json files carry the version. Only
# plugins touched by the current range are in scope; a bump to the marketplace
# file alone does not pull any plugin in.
IN_SCOPE_PLUGINS=()
if [ "$MANIFEST" = "none" ] && [ -f ".claude-plugin/marketplace.json" ]; then
  CHANGED_FILES=$(git diff --name-only "$RANGE" 2>/dev/null || true)
  SLUGS=$(echo "$CHANGED_FILES" | grep -oE '^plugins/[^/]+/' | sed -E 's|^plugins/([^/]+)/|\1|' | sort -u)
  VERSIONS=""
  for slug in $SLUGS; do
    manifest="plugins/${slug}/.claude-plugin/plugin.json"
    if [ -f "$manifest" ] && [ -r "$manifest" ]; then
      V=$(jq -r '.version // empty' "$manifest" 2>/dev/null || true)
      if [ -n "$V" ]; then
        IN_SCOPE_PLUGINS+=("$slug")
        VERSIONS="${VERSIONS}${V}
"
      fi
    fi
  done
  if [ "${#IN_SCOPE_PLUGINS[@]}" -gt 0 ]; then
    OLD=$(printf '%s' "$VERSIONS" | sort -V | tail -n1)
    MANIFEST="claude-plugin:${#IN_SCOPE_PLUGINS[@]}"
  fi
fi

# Compute new version
compute_new() {
  local level=$1 old=$2
  case "$old" in
    *.*.*) : ;;
    *) old="0.0.0" ;;
  esac
  local major minor patch
  major=${old%%.*}
  rest=${old#*.}
  minor=${rest%%.*}
  patch=${rest#*.}
  # strip pre-release tags on patch
  patch=${patch%%-*}
  case "$level" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "${major}.$((minor + 1)).0" ;;
    patch) echo "${major}.${minor}.$((patch + 1))" ;;
    none)  echo "$old" ;;
  esac
}

NEW=$(compute_new "$LEVEL" "$OLD")

if [ "$APPLY" -eq 1 ] && [ "$LEVEL" != "none" ] && [ "$MANIFEST" != "none" ]; then
  case "$MANIFEST" in
    package.json)
      tmp=$(mktemp)
      jq --arg v "$NEW" '.version = $v' package.json > "$tmp" && mv "$tmp" package.json
      ;;
    pyproject.toml)
      sed -i.bak -E "s/^(version\s*=\s*)\"[^\"]+\"/\1\"${NEW}\"/" pyproject.toml && rm -f pyproject.toml.bak
      ;;
    Cargo.toml)
      awk -v new="$NEW" '
        /^\[package\]/{p=1; print; next}
        /^\[/{p=0; print; next}
        p && /^version\s*=/{print "version = \"" new "\""; next}
        {print}
      ' Cargo.toml > Cargo.toml.tmp && mv Cargo.toml.tmp Cargo.toml
      ;;
    *.csproj)
      sed -i.bak -E "s|<Version>[^<]+</Version>|<Version>${NEW}</Version>|" "$MANIFEST" && rm -f "${MANIFEST}.bak"
      ;;
    *.gemspec)
      sed -i.bak -E "s/(version\s*=\s*[\"'])[^\"']+([\"'])/\1${NEW}\2/" "$MANIFEST" && rm -f "${MANIFEST}.bak"
      ;;
  esac
fi

echo "${LEVEL} ${OLD} ${NEW} ${MANIFEST}"
