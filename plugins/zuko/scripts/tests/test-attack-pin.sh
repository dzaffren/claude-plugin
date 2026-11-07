# scripts/check-attack-pin.sh -- the notice that upstream changed a copied
# attack-class file after the pin (spec attack-classes, scenarios 4 and 5).
# It only ever tells, and it is silent whenever it cannot know (D93).
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

work=$(mktemp -d -p "$work")
pin_sha=c1c8a8c1471069fb0e188eeaff69b8e8db6564a8

# A stand-in for gh, first on PATH. The compare answer is in $FAKE_GH/files,
# with Windows line ends, and every call goes to $FAKE_GH/calls.
mkdir -p "$work/bin"
export FAKE_GH="$work/gh"
cat >"$work/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_GH/calls"
if [ -f "$FAKE_GH/api-error" ]; then cat "$FAKE_GH/api-error" >&2; exit 1; fi
case "$1 $2" in
  "api repos/cloudflare/security-audit-skill/compare/"*)
    cat "$FAKE_GH/files"
    # A renamed file: GitHub lists the new path as filename, and the old one
    # only as previous_filename, which --jq prints only when it asks for it.
    if [ -f "$FAKE_GH/renamed" ]; then
      while read -r old new; do
        printf '%s\r\n' "$new"
        case "$*" in *previous_filename*) printf '%s\r\n' "$old" ;; esac
      done <"$FAKE_GH/renamed"
    fi ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"

gh_files() {    # gh_files <path>...: the file names the compare returns
  rm -rf "$FAKE_GH"; mkdir -p "$FAKE_GH"
  printf '%s\r\n' "$@" >"$FAKE_GH/files"
}
gh_renamed() {  # gh_renamed <old path> <new path>: the compare returns one rename
  gh_files README.md
  printf '%s %s
' "$1" "$2" >"$FAKE_GH/renamed"
}
pin() { bash "$scripts/check-attack-pin.sh" 2>&1; }

# A copy of the script in its own plugin tree, so a test can give it any README.
fake_tree() {   # fake_tree <case> <README text> <copied name>...
  local root="$work/$1"; shift
  mkdir -p "$root/scripts" "$root/references/attack-classes"
  cp "$scripts/check-attack-pin.sh" "$root/scripts/"
  printf '%s\n' "$1" >"$root/references/attack-classes/README.md"; shift
  local name
  for name in "$@"; do : >"$root/references/attack-classes/$name"; done
}
pin_in() { bash "$work/$1/scripts/check-attack-pin.sh" 2>&1; }

bash -n "$scripts/check-attack-pin.sh" 2>/dev/null
expect_exit 0 "$?" "the pin check parses"

# Scenario 4: upstream changed one copied file. The real README gives the pin.
gh_files README.md skills/security-audit/AI-AND-LLM.md
out=$(pin)
expect_exit 0 "$?" "a changed copied file exits 0: it is a notice, not a gate"
expect_exit 0 "$([ "$out" = "attack-classes: upstream changed AI-AND-LLM.md after c1c8a8c. This pentest uses the pinned copy." ]; echo $?)" "a changed copied file prints exactly the notice line"
expect_exit 0 "$([ "$(cat "$FAKE_GH/calls" 2>/dev/null)" = "api repos/cloudflare/security-audit-skill/compare/$pin_sha...main --jq .files[] | .filename, (.previous_filename // empty)" ]; echo $?)" "it makes one compare call from the pin in the real README"

# Two copied files changed: one line, names in sorted order.
gh_files skills/security-audit/SUPPLY-CHAIN-AND-RELEASE.md README.md skills/security-audit/AI-AND-LLM.md
out=$(pin)
expect_exit 0 "$([ "$out" = "attack-classes: upstream changed AI-AND-LLM.md, SUPPLY-CHAIN-AND-RELEASE.md after c1c8a8c. This pentest uses the pinned copy." ]; echo $?)" "two changed copied files give one line with a sorted comma list"

# A copied file renamed upstream is a change to it, so it gets the notice too.
gh_renamed skills/security-audit/AI-AND-LLM.md skills/security-audit/AI-AND-AGENTS.md
out=$(pin)
expect_exit 0 "$([ "$out" = "attack-classes: upstream changed AI-AND-LLM.md after c1c8a8c. This pentest uses the pinned copy." ]; echo $?)" "a copied file renamed upstream prints the notice with its old name"

# Scenario 5: only files that are not copied changed.
gh_files README.md skills/security-audit/HUNTING.md vendor/skills/security-audit/AI-AND-LLM.md
out=$(pin)
expect_exit 0 "$?" "upstream changes to other files exit 0"
expect_exit 0 "$([ -z "$out" ]; echo $?)" "upstream changes to other files print nothing"

# A gh error (offline, rate-limited): silent.
gh_files skills/security-audit/AI-AND-LLM.md
printf 'error connecting to api.github.com\n' >"$FAKE_GH/api-error"
out=$(pin)
expect_exit 0 "$?" "a gh error exits 0"
expect_exit 0 "$([ -z "$out" ]; echo $?)" "a gh error prints nothing"

# No gh at all: PATH keeps every directory except the ones that hold a gh.
nogh=""
IFS=: read -ra dirs <<<"$PATH"
for d in "${dirs[@]}"; do
  [ -n "$d" ] && [ ! -e "$d/gh" ] && [ ! -e "$d/gh.exe" ] && nogh="${nogh:+$nogh:}$d"
done
gh_files skills/security-audit/AI-AND-LLM.md
expect_exit 1 "$(PATH="$nogh" command -v gh >/dev/null 2>&1; echo $?)" "the no-gh PATH has no gh on it"
out=$(PATH="$nogh" "$BASH" "$scripts/check-attack-pin.sh" 2>&1)
expect_exit 0 "$?" "no gh on PATH exits 0"
expect_exit 0 "$([ -z "$out" ] && [ ! -f "$FAKE_GH/calls" ]; echo $?)" "no gh on PATH prints nothing"

# The copied names come from the folder, and README.md is never one.
gh_files skills/security-audit/README.md skills/security-audit/FOO.md
fake_tree names "Pinned: $pin_sha" FOO.md
out=$(pin_in names)
expect_exit 0 "$([ "$out" = "attack-classes: upstream changed FOO.md after c1c8a8c. This pentest uses the pinned copy." ]; echo $?)" "the copied names are the folder's .md files except README.md"

# A README with no Pinned line: nothing to check, gh never runs.
gh_files skills/security-audit/FOO.md
fake_tree nopin "# Attack classes" FOO.md
out=$(pin_in nopin)
expect_exit 0 "$?" "a README with no Pinned line exits 0"
expect_exit 0 "$([ -z "$out" ] && [ ! -f "$FAKE_GH/calls" ]; echo $?)" "a README with no Pinned line prints nothing and calls no gh"

# The pin is data: anything that is not 40 lowercase hex never reaches gh.
gh_files skills/security-audit/FOO.md
fake_tree badpin "Pinned: $pin_sha;touch pwned" FOO.md
out=$(cd "$work/badpin" && pin_in badpin)
expect_exit 0 "$?" "a pin with a ; in it exits 0"
expect_exit 0 "$([ -z "$out" ] && [ ! -f "$FAKE_GH/calls" ] && [ ! -f "$work/badpin/pwned" ]; echo $?)" "a pin with a ; in it prints nothing, runs nothing and calls no gh"
