# scripts/check-skill-pin.sh -- the update notice for a skill pinned by tag in
# skills-lock.json (spec taste-skill-upgrade, scenario 2). It only ever tells:
# it never changes the lock, and it is silent whenever it cannot know.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

# A stand-in for gh, first on PATH. It answers from files in $FAKE_GH and logs
# every call to $FAKE_GH/calls.
mkdir -p "$work/bin"
export FAKE_GH="$work/gh"
cat >"$work/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_GH/calls"
if [ -f "$FAKE_GH/api-error" ]; then cat "$FAKE_GH/api-error" >&2; exit 1; fi
case "$1 $2" in
  "api repos/"*/releases/latest) cat "$FAKE_GH/latest" ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"

proj="$work/skill-pin"
mkdir -p "$proj"
lock_with() {   # lock_with <source> <ref>: a lock holding design-taste-frontend
  printf '{"version": 1, "skills": {"design-taste-frontend": {"source": "%s", "ref": "%s", "sourceType": "github", "computedHash": "x"}}}\n' "$1" "$2" >"$proj/skills-lock.json"
}
gh_reset() { rm -rf "$FAKE_GH"; mkdir -p "$FAKE_GH"; printf 'v2.1.5\n' >"$FAKE_GH/latest"; }
pin() { (cd "$proj" && CLAUDE_PROJECT_DIR="$proj" bash "$scripts/check-skill-pin.sh" "$@" 2>&1); }

bash -n "$scripts/check-skill-pin.sh" 2>/dev/null
expect_exit 0 "$?" "the pin check parses"

# A newer upstream release gets the notice, and the lock stays as it was.
gh_reset; lock_with Leonxlnx/taste-skill v2.1.5
printf 'v2.2.0\n' >"$FAKE_GH/latest"
before=$(cat "$proj/skills-lock.json")
out=$(pin design-taste-frontend)
expect_exit 0 "$?" "a newer release exits 0: it is a notice, not a gate"
expect_match '^design-taste-frontend: v2\.2\.0 is out, pinned at v2\.1\.5\. Edit the pin in skills-lock\.json to move\.$' "$out" "a newer release prints the update notice"
expect_exit 0 "$([ "$before" = "$(cat "$proj/skills-lock.json")" ]; echo $?)" "the notice never changes the lock"
expect_match '^api repos/Leonxlnx/taste-skill/releases/latest' "$(cat "$FAKE_GH/calls")" "it asks GitHub for the pinned repo's latest release"

# The pin is the latest release: nothing to say.
gh_reset; lock_with Leonxlnx/taste-skill v2.1.5
out=$(pin design-taste-frontend)
expect_exit 0 "$?" "an up-to-date pin exits 0"
expect_exit 0 "$([ -z "$out" ]; echo $?)" "an up-to-date pin prints nothing"

# Offline, rate-limited or any gh error: silent, and the stage goes on.
gh_reset; lock_with Leonxlnx/taste-skill v2.1.5
printf 'error connecting to api.github.com\n' >"$FAKE_GH/api-error"
out=$(pin design-taste-frontend)
expect_exit 0 "$?" "a gh error exits 0"
expect_exit 0 "$([ -z "$out" ]; echo $?)" "a gh error prints nothing"

# No gh at all: only python3 is on PATH.
gh_reset; lock_with Leonxlnx/taste-skill v2.1.5
mkdir -p "$work/nogh"
py=$(command -v python3)
printf '#!/bin/sh\nexec "%s" "$@"\n' "$py" >"$work/nogh/python3"
chmod +x "$work/nogh/python3"
out=$(cd "$proj" && CLAUDE_PROJECT_DIR="$proj" PATH="$work/nogh" "$BASH" "$scripts/check-skill-pin.sh" design-taste-frontend 2>&1)
expect_exit 0 "$?" "no gh on PATH exits 0"
expect_exit 0 "$([ -z "$out" ]; echo $?)" "no gh on PATH prints nothing"

# A project with no pin for this skill: nothing to check, gh never runs.
gh_reset
printf '{"version": 1, "skills": {"shadcn": {"source": "shadcn/ui", "sourceType": "github", "computedHash": "x"}}}\n' >"$proj/skills-lock.json"
out=$(pin design-taste-frontend)
expect_exit 0 "$?" "a skill not in the lock exits 0"
expect_exit 0 "$([ -z "$out" ] && [ ! -f "$FAKE_GH/calls" ]; echo $?)" "a skill not in the lock prints nothing and calls no gh"

printf '{"version": 1, "skills": {"design-taste-frontend": {"source": "Leonxlnx/taste-skill", "sourceType": "github", "computedHash": "x"}}}\n' >"$proj/skills-lock.json"
out=$(pin design-taste-frontend)
expect_exit 0 "$([ -z "$out" ] && [ ! -f "$FAKE_GH/calls" ]; echo $?)" "an entry with no ref is not pinned: nothing printed, no gh call"

rm -f "$proj/skills-lock.json"
out=$(pin design-taste-frontend)
expect_exit 0 "$?" "a project with no skills-lock.json exits 0"
expect_exit 0 "$([ -z "$out" ] && [ ! -f "$FAKE_GH/calls" ]; echo $?)" "a project with no skills-lock.json prints nothing"

# The source comes from a file in the project. It is data: anything that is
# not owner/repo never reaches gh.
gh_reset; lock_with 'evil/x$(touch pwned)' v2.1.5
out=$(pin design-taste-frontend)
expect_exit 0 "$([ ! -f "$proj/pwned" ] && [ ! -f "$FAKE_GH/calls" ]; echo $?)" "a source that is not owner/repo runs nothing and calls no gh"

gh_reset; lock_with Leonxlnx/taste-skill v2.1.5
out=$(pin 2>&1)
expect_exit 2 "$?" "no skill name is a usage error"
expect_match 'Usage: check-skill-pin\.sh <skill>' "$out" "the usage error says what to pass"
