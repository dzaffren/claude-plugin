# The rendered-drift-check slice, end to end: check-rendered-drift.sh opens
# the Invoices fixture in a real headless browser, light then dark, and judges
# each element's computed style against the fixture's tokens.css.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.
#
# It needs Node 22 and Chrome, Edge or Chromium. When either is missing, the
# test fails and says which: a slice e2e that could not run is not a pass.

fx="$scripts/tests/fixtures/rendered-drift"
proj="$fx/project"
# The real interpreter: on Windows a python3 shim runs python.exe as its child,
# so the server's pid would be the shim and not the process on the port.
py=$(python3 -c 'import sys; print(sys.executable)')
rd() {   # rd <project-dir> <args...>: run the gate from that project, stderr too
  local p="$1"; shift
  (cd "$p" && CLAUDE_PROJECT_DIR="$p" bash "$scripts/check-rendered-drift.sh" "$@" 2>&1)
}

# One run first. When it cannot render (no Node 22, or no browser), record one
# FAIL that names the missing part, in the gate's own words (E1, E2 or E3).
preflight=$(rd "$proj" clean.html)
if [ $? -eq 2 ]; then
  record FAIL "the e2e could not run, so it proves nothing: ${preflight##*$'\n'}"
  return 0
fi

# Scenario 1: rgb() passes the source check and fails the rendered one.
(cd "$proj" && CLAUDE_PROJECT_DIR="$proj" bash "$scripts/check-design-drift.sh" drift.html >/dev/null 2>&1)
expect_exit 0 "$?" "scenario 1: check-design-drift.sh passes on drift.html"
start=$(date +%s)
out=$(rd "$proj" drift.html)
code=$?
took=$(( $(date +%s) - start ))
expect_exit 1 "$code" "scenario 1: an off-token rgb() colour exits 1"
expect_match '^Rendered drift check FAILED: 3 values over 1 page are not design system tokens\.$' "$out" "scenario 1: the report counts the values and the pages"
expect_match '^  both +td\.overdue +color +rgb\(220, 38, 38\) +x2 +nearest --danger #b42318$' "$out" "scenario 1: the rgb() colour is reported with its nearest token"
expect_match '^  both +h2\.section-title +font-size +22px +nearest --text-lg 20px$' "$out" "an off-token font size fails in both modes"
expect_match '^Fix these with tokens and re-render before showing the user\.' "$out" "a FAIL ends with the fix line"
expect_exit 0 "$([ "$took" -lt 15 ]; echo $?)" "one page renders and exits in under 15 s (took ${took} s)"

# Scenario 3: a colour set for dark mode only.
expect_match '^  dark +div\.invoice-total +background-color +rgb\(51, 51, 51\) +nearest --surface #111111$' "$out" "scenario 3: a dark-only drift is reported as dark"

# Scenario 3, class-based dark mode: the .dark class is set for the dark render.
out=$(rd "$proj" dark-class.html)
expect_exit 1 "$?" "a .dark-class drift exits 1"
expect_match '^  dark +div\.badge +background-color +rgb\(77, 77, 77\) ' "$out" "the dark render sets class=\"dark\" on <html>"

# Scenario 2: only token values pass, with the scope in the line. The svg's
# crimson fill is skipped, and the web font request is blocked and named.
out=$(rd "$proj" clean.html)
expect_exit 0 "$?" "scenario 2: a preview that uses only tokens exits 0"
expect_match '^Rendered drift check passed: [0-9]+ elements over 1 page, light and dark, against 8 token values\.$' "$out" "scenario 2: the pass line names its scope"
expect_no_match 'crimson|circle' "$out" "the contents of an svg are not judged"
expect_match '^Rendered drift check blocked 1 request to other hosts: fonts\.googleapis\.com\.$' "$out" "a request to another host is blocked and named"

# A folder renders each .html file in it.
out=$(rd "$proj" .)
expect_exit 1 "$?" "a folder with a drifted page exits 1"
expect_match 'over 4 pages' "$out" "a folder renders each of its .html files"

# Scenario 5 and the other ways of having nothing to compare against.
out=$(rd "$fx/no-tokens" preview.html)
expect_exit 1 "$?" "scenario 5: no token file exits 1"
expect_match '^Rendered drift check has nothing to compare against: no design system token file found\.$' "$out" "scenario 5: no token file prints E7"
out=$(rd "$proj" unlinked.html)
expect_exit 1 "$?" "a page that loads none of the tokens exits 1"
expect_match '^Rendered drift check has nothing to compare against: unlinked\.html loads none of the 8 tokens in tokens\.css\.$' "$out" "a page that loads none of the tokens prints E8"
out=$(rd "$fx/tailwind-only" preview.html)
expect_exit 2 "$?" "tokens only in tailwind.config exit 2"
expect_match '^Rendered drift check could not run: the tokens live in tailwind\.config\.js, not in CSS variables\.$' "$out" "tokens only in tailwind.config print E9"

# Scenario 4 with a browser path that holds nothing: CHROME_PATH is used alone.
out=$(cd "$proj" && CHROME_PATH=/no/chrome CLAUDE_PROJECT_DIR="$proj" bash "$scripts/check-rendered-drift.sh" clean.html 2>&1)
expect_exit 2 "$?" "scenario 4: a CHROME_PATH with no browser exits 2, never 0"
# Git Bash hands a native Node the path as C:/Program Files/Git/no/chrome.
expect_match '^Rendered drift check could not run: CHROME_PATH is (/|[A-Z]:/.*/)no/chrome, and no browser is there\.$' "$out" "scenario 4: a wrong CHROME_PATH prints E3"

# Hosts: only localhost and 127.0.0.1, compared exactly.
for url in https://staging.example.com/invoices http://localhost.evil.example/ http://127.0.0.1@evil.example/; do
  out=$(rd "$proj" "$url")
  expect_exit 2 "$?" "$url is refused with exit 2"
  expect_match "^Rendered drift check refused .*: only localhost and 127\\.0\\.0\\.1 may be opened\\.$" "$out" "$url prints E4"
done
out=$(rd "$proj" http://127.0.0.1:9/invoices)
expect_exit 2 "$?" "a local URL that does not answer exits 2"
expect_match '^Rendered drift check could not load http://127\.0\.0\.1:9/invoices: ' "$out" "a local URL that does not answer prints E6"

# Nothing to render.
out=$(rd "$proj")
expect_exit 2 "$?" "no target exits 2"
expect_match '^Rendered drift check rendered NOTHING: ' "$out" "no target prints E5"
out=$(rd "$proj" tokens.css missing.html)
expect_exit 2 "$?" "a .css file and a missing path render nothing and exit 2"
expect_match '^Rendered drift check rendered NOTHING: no \.html file or localhost URL in tokens\.css missing\.html\.$' "$out" "a target with no page prints E5 with the targets"

# Review A4 (D87): a WebSocket to a host that is not local must not connect.
# 127.0.0.2 is not on the list, so it stands in for a far host.
start_server() {   # start_server <mode> <host> <name>: sets server_pid and server_port
  rm -f "$work/$3.port"
  "$py" "$fx/server.py" "$1" "$2" "$work/$3.port" "$work/$3.log" >/dev/null 2>&1 &
  server_pid=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$work/$3.port" ] && break; sleep 0.3; done
  server_port=$(cat "$work/$3.port" 2>/dev/null)
}
ws="$work/rendered-ws"
mkdir -p "$ws"
cp "$proj/tokens.css" "$ws/"
start_server listen 127.0.0.2 far
printf '<!doctype html><html><head><link rel="stylesheet" href="tokens.css"></head><body style="background: var(--surface); color: var(--ink); font-family: var(--font-sans); font-size: var(--text-base); margin: 0"><p>Invoices</p><script>new WebSocket("ws://127.0.0.2:%s/live");</script></body></html>\n' "$server_port" >"$ws/ws.html"
out=$(rd "$ws" ws.html)
stop_tree "$server_pid"
expect_exit 0 "$([ ! -s "$work/far.log" ]; echo $?)" "a WebSocket to a host that is not local does not connect"

# Review A1: a localhost URL that answers with an HTTP error is not the preview.
# The fixture's not-found page uses only tokens, so judging it would pass.
start_server http404 127.0.0.1 nf
out=$(rd "$ws" "http://127.0.0.1:$server_port/preview/invoicez")
code=$?
stop_tree "$server_pid"
expect_exit 2 "$code" "a localhost page that answers 404 exits 2, never 0"
expect_match "^Rendered drift check could not load http://127\.0\.0\.1:$server_port/preview/invoicez: HTTP 404\.\$" "$out" "a 404 page prints E6 with its status"

# Review A2: when the page's own script does not run, the page on screen is not
# the preview. A module script under a file: URL is refused by the browser, and
# a script from another host is blocked (D87). Either leaves an empty root that
# would pass.
mod="$work/rendered-module"
mkdir -p "$mod"
cp "$proj/tokens.css" "$mod/"
printf 'document.getElementById("root").innerHTML = "<p style=\\"color: rgb(220, 38, 38)\\">Overdue 12 days</p>";\n' >"$mod/app.js"
page_with() {   # page_with <script tag>: a preview whose UI comes from that script
  printf '<!doctype html><html><head><link rel="stylesheet" href="tokens.css"></head><body style="background: var(--surface); color: var(--ink); font-family: var(--font-sans); font-size: var(--text-base); margin: 0"><div id="root"></div>%s</body></html>\n' "$1"
}
page_with '<script type="module" src="app.js"></script>' >"$mod/module.html"
page_with '<script src="https://cdn.example.com/app.js"></script>' >"$mod/cdn.html"
page_with '<script src="app.js"></script>' >"$mod/classic.html"
out=$(rd "$mod" module.html)
expect_exit 2 "$?" "a module script that does not load exits 2, never 0"
expect_match '^Rendered drift check could not load module\.html: the script .*app\.js did not load' "$out" "a module script that does not load prints E6 with the script"
out=$(rd "$mod" cdn.html)
expect_exit 2 "$?" "a script from another host exits 2, never 0"
expect_match '^Rendered drift check could not load cdn\.html: the script https://cdn\.example\.com/app\.js was blocked' "$out" "a blocked script prints E6 with the script"
out=$(rd "$mod" classic.html)
expect_exit 1 "$?" "the same UI from a classic script is judged, and fails"

# Review A3: shadcn tokens are bare HSL channels (--background: 0 0% 100%),
# used as hsl(var(--background)) and, with an alpha, hsl(var(--primary) / 0.9).
out=$(rd "$fx/shadcn" preview.html)
expect_exit 0 "$?" "a preview on shadcn channel tokens passes"
expect_match 'against 7 token values\.$' "$out" "shadcn channel tokens are counted as colours"
out=$(rd "$fx/shadcn" drift.html)
expect_exit 1 "$?" "an off-token colour still fails beside shadcn tokens"
expect_match '^  both +p\.muted +color +rgb\(128, 128, 128\) +nearest --' "$out" "the off-token colour is reported with a channel token as nearest"
