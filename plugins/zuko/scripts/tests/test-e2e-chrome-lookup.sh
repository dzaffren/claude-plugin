# One walk through chrome-lookup: a chrome.exe planted in the project folder
# never runs from the rendered drift check (D134). On Linux and macOS the
# Windows variables are not set, so findChrome() built relative candidates.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

lib="$scripts/lib"
work=$(mktemp -d -p "$work")
repo="$work/acme-shop"
cp -R "$scripts/tests/fixtures/rendered-drift/project" "$repo"

# The candidate paths that an unset variable makes relative. A name with : or \
# is not a valid Windows file name, so Windows plants the other two only.
rel=('Google/Chrome/Application/chrome.exe' 'Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
is_windows || rel+=('C:\Program Files/Google/Chrome/Application/chrome.exe')
for r in "${rel[@]}"; do
  mkdir -p "$repo/$(dirname "$r")"
  printf '#!/bin/sh\ntouch planted-ran\n' > "$repo/$r"
  chmod +x "$repo/$r"
done

# Every OS: with the variables unset, findChrome() gives an absolute path or null.
vars=(-u LOCALAPPDATA -u PROGRAMFILES -u 'PROGRAMFILES(X86)' -u HOME -u USERPROFILE -u CHROME_PATH)
want='^(true .+|null)$'
if is_windows; then
  # Program Files comes first and holds the runner's Chrome, so point it at an
  # empty folder: only a planted relative candidate can then be found.
  empty=$(cygpath -w "$(mktemp -d -p "$work")")
  vars=(-u LOCALAPPDATA -u HOME -u USERPROFILE -u CHROME_PATH "PROGRAMFILES=$empty" "PROGRAMFILES(X86)=$empty")
  want='^null$'
fi
found=$(cd "$repo" && env "${vars[@]}" \
  node -e "import(require('node:url').pathToFileURL(process.argv[1])).then((m) => { const c = m.findChrome(); console.log(c === null ? 'null' : require('node:path').isAbsolute(c) + ' ' + c); })" "$lib/cdp.mjs" 2>&1)
expect_match "$want" "$found" "findChrome() in acme-shop gives no relative path [$found]"

if is_windows; then
  skip "e2e-chrome-lookup: a chrome.exe planted in the repo never runs from the drift check" \
    "Windows finds Chrome in Program Files before the LOCALAPPDATA candidate; the findChrome() check above covers it"
  return 0 2>/dev/null || exit 0
fi

# The hole is real here: Node runs a relative path from the current folder.
(cd "$repo" && node -e "require('node:child_process').spawnSync('Google/Chrome/Application/chrome.exe', [], { stdio: 'ignore' })")
expect_exit 0 "$([ -f "$repo/planted-ran" ]; echo $?)" "a spawn of the relative candidate in acme-shop runs the planted chrome.exe"
rm -f "$repo/planted-ran"

out=$(cd "$repo" && env -u LOCALAPPDATA -u PROGRAMFILES -u CHROME_PATH CLAUDE_PROJECT_DIR="$repo" bash "$scripts/check-rendered-drift.sh" clean.html 2>&1)
code=$?
expect_exit 0 "$([ ! -f "$repo/planted-ran" ]; echo $?)" "the planted chrome.exe did not run from the drift check"
if [ "$code" -eq 2 ] && [ ! -f "$repo/planted-ran" ]; then
  record FAIL "the e2e could not run, so it proves nothing: ${out##*$'\n'}"
  return 0
fi
expect_exit 0 "$code" "the drift check on clean.html in acme-shop exits 0"
expect_match '^Rendered drift check passed: ' "$out" "the drift check prints its pass line"
