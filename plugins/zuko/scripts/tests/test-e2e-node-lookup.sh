# One walk through node-lookup: on Windows, a taskkill.exe at the root of the
# project folder never runs from the rendered drift check (D127). The planted
# taskkill.exe is a copy of Git Bash's mkdir.exe, so when it runs, it leaves a
# folder named after Chrome's pid in the project folder.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

# Every OS: no spawn in zuko's Node starts a program by a bare name. Libuv
# looks in the current folder first for a name with no folder in it.
lib="$scripts/lib"
calls='(^|[^.A-Za-z_$])(spawn|spawnSync|execFile|execFileSync|exec|execSync)\('
bare="$calls"'[[:space:]]*['"'"'"`]'
found=$(cat "$lib"/*.mjs | grep -cE "$calls")
expect_exit 0 "$([ "$found" -ge 2 ]; echo $?)" "the bare-name check reads the spawn calls in lib/*.mjs (found $found)"
expect_match "$bare" "spawnSync('taskkill', ['/pid', String(pid)])" "the bare-name check catches spawnSync('taskkill', ...)"
expect_no_match "$bare" "$(grep -nE "$calls" "$lib"/*.mjs)" "no spawn in lib/*.mjs starts a program by a bare name"

if ! is_windows; then
  skip "e2e-node-lookup: a taskkill.exe at the repo root never runs from the drift check" \
    "libuv looks in the current folder on Windows only; the bare-name check above covers every OS"
  return 0 2>/dev/null || exit 0
fi

work=$(mktemp -d -p "$work")
repo="$work/acme-shop"
cp -R "$scripts/tests/fixtures/rendered-drift/project" "$repo"
cp /usr/bin/mkdir.exe "$repo/taskkill.exe"
numbered() { find "$repo" -maxdepth 1 -type d -regex '.*/[0-9]+' | sort; }

# The hole is real here: a bare "taskkill" from Node runs the planted copy.
(cd "$repo" && node -e "require('node:child_process').spawnSync('taskkill', ['4242'], { stdio: 'ignore' })")
expect_match "/4242$" "$(numbered)" "a bare taskkill from Node in acme-shop runs the planted taskkill.exe"
rmdir "$repo/4242" 2>/dev/null

temp=$(cygpath -u "$(node -p "require('node:os').tmpdir()")")
profiles() { find "$temp" -maxdepth 1 -name 'zuko-chrome-*' | sort; }
before=$(profiles)
out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/check-rendered-drift.sh" clean.html 2>&1)
code=$?
if [ "$code" -eq 2 ]; then
  record FAIL "the e2e could not run, so it proves nothing: ${out##*$'\n'}"
  return 0
fi
expect_exit 0 "$code" "the drift check on clean.html in acme-shop exits 0"
expect_match '^Rendered drift check passed: ' "$out" "the drift check prints its pass line"
expect_exit 0 "$([ -z "$(numbered)" ]; echo $?)" "the planted taskkill.exe did not run: no pid folder in acme-shop [$(numbered)]"
expect_exit 0 "$([ "$(profiles)" = "$before" ]; echo $?)" "the taskkill.exe in System32 ended Chrome: no zuko-chrome- profile folder stays"
