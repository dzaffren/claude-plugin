#!/usr/bin/env bash
# Notice: a skill pinned by tag in skills-lock.json has a newer upstream release.
# Usage: check-skill-pin.sh <skill>
# The design stages run it before they load the craft chain (D78). It only
# tells: it never edits the lock. When it cannot know -- no lock, no pin for
# this skill, no gh, offline, rate-limited -- it prints nothing and exits 0,
# so the stage goes on.
set -uo pipefail

skill="${1:-}"
if [ -z "$skill" ]; then
  echo "Usage: check-skill-pin.sh <skill>   (a name from skills-lock.json)" >&2
  exit 2
fi

lock="${CLAUDE_PROJECT_DIR:-$PWD}/skills-lock.json"
[ -f "$lock" ] || exit 0
command -v gh >/dev/null 2>&1 || exit 0

# Prints "<source> <ref>" for a GitHub entry pinned to a ref, else nothing.
# The source is data from the project: only a plain owner/repo goes to gh.
read -r source ref < <(python3 - "$lock" "$skill" <<'PY' 2>/dev/null
import json, re, sys
for stream in (sys.stdin, sys.stdout, sys.stderr):
    stream.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n")
try:
    entry = json.load(open(sys.argv[1], encoding="utf-8"))["skills"][sys.argv[2]]
except Exception:
    sys.exit(0)
source, ref = entry.get("source", ""), entry.get("ref", "")
if entry.get("sourceType") == "github" and ref \
        and re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", source) \
        and re.fullmatch(r"[A-Za-z0-9_.+-]+", ref):
    print(source, ref)
PY
)
ref=${ref%$'\r'}   # print() ends the line with \r\n on Windows
[ -n "${source:-}" ] || exit 0

latest=$(gh api "repos/$source/releases/latest" --jq .tag_name 2>/dev/null) || exit 0
latest=${latest%$'\r'}
if [ -n "$latest" ] && [ "$latest" != "$ref" ]; then
  echo "$skill: $latest is out, pinned at $ref. Edit the pin in skills-lock.json to move."
fi
exit 0
