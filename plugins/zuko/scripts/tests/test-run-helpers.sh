# run.sh's own expect_match and expect_no_match, on text short and long.
# Sourced by run.sh, which provides the expect_* helpers and $results_file.
#
# Each helper is called with its results pointed at a scratch file, so a
# helper that reports wrongly shows up here as a wrong record, not as a
# failure of this file.

helper_record() {   # helper_record <helper> <regex> <text>; prints PASS or FAIL
  local real="$results_file" scratch
  scratch=$(mktemp -p "$work")
  results_file="$scratch"
  "$1" "$2" "$3" "probe"
  results_file="$real"
  cut -f1 "$scratch"
}

short="NEEDLE
tail"
# Past the 64 KB pipe buffer, with the match on the first line.
long="NEEDLE
$(head -c 200000 /dev/zero | tr '\0' x)"
# Long, with no match anywhere.
long_miss=$(head -c 200000 /dev/zero | tr '\0' x)

expect_match '^PASS$' "$(helper_record expect_match NEEDLE "$short")" \
  "expect_match passes on a short text that matches"
expect_match '^PASS$' "$(helper_record expect_match NEEDLE "$long")" \
  "expect_match passes on a 200 KB text that matches on its first line"
expect_match '^FAIL$' "$(helper_record expect_match NEEDLE "$long_miss")" \
  "expect_match fails on a 200 KB text with no match"
expect_match '^FAIL$' "$(helper_record expect_no_match NEEDLE "$long")" \
  "expect_no_match fails on a 200 KB text that matches on its first line"
expect_match '^PASS$' "$(helper_record expect_no_match NEEDLE "$long_miss")" \
  "expect_no_match passes on a 200 KB text with no match"

# A pattern that starts with "-" is a pattern, not a grep option.
dash="- code, commands and paths"
expect_match '^PASS$' "$(helper_record expect_match '- code' "$dash")" \
  "expect_match passes on a pattern that starts with -"
expect_match '^FAIL$' "$(helper_record expect_no_match '- code' "$dash")" \
  "expect_no_match fails on a pattern that starts with - and matches"

# --- run.sh in a sandbox, with fixture test files (portable-suite) ---
sandbox() {   # sandbox <name> <body>: a copy of run.sh beside one fixture test file
  local sb
  sb=$(mktemp -d -p "$work")
  mkdir -p "$sb/tests"
  cp "$scripts/tests/run.sh" "$sb/tests/run.sh"
  printf '%s\n' "$2" >"$sb/tests/test-$1.sh"
  printf '%s' "$sb"
}

# Scenario 4: a skipped check is named with its reason, and never counted as passed.
sb=$(sandbox skips 'expect_exit 0 0 "ran"
skip "symlink: exits 0" "ln -s made a copy, not a link"')
out=$(bash "$sb/tests/run.sh" skips 2>&1)
expect_exit 0 "$?" "skip: run.sh exits 0 when only a skip and passes were recorded"
expect_match '^skips +1 passed, 1 skipped$' "$out" "skip: the file line counts the skip apart from the passes"
expect_match '^  SKIP  symlink: exits 0$' "$out" "skip: the skipped check is named"
expect_match '^        ln -s made a copy, not a link$' "$out" "skip: the reason prints under it"
expect_match '^ +1 passed, 0 failed, 1 skipped$' "$(printf '%s\n' "$out" | tail -1)" "skip: the last line has all three counts"

sb=$(sandbox plain 'expect_exit 0 0 "ran"')
out=$(bash "$sb/tests/run.sh" plain 2>&1)
expect_match '^plain +1 passed$' "$out" "no skip: the file line is unchanged"
expect_match '^ +1 passed, 0 failed, 0 skipped$' "$(printf '%s\n' "$out" | tail -1)" "no skip: the last line still has three counts"

# Scenario 3: a file past the limit fails, and a server it started is stopped.
sb=$(sandbox slow 'python3 -c "
import socket, sys
s = socket.socket(); s.bind((\"127.0.0.1\", 0)); s.listen()
open(sys.argv[1] + \".tmp\", \"w\").write(str(s.getsockname()[1]))
import os; os.replace(sys.argv[1] + \".tmp\", sys.argv[1])
while True: s.accept()[0].close()
" "$SANDBOX_PORT" >/dev/null 2>&1 &
expect_exit 0 0 "before the limit"
sleep 30')
started=$SECONDS
out=$(SANDBOX_PORT="$sb/port" ZUKO_TEST_LIMIT=2 bash "$sb/tests/run.sh" slow 2>&1)
status=$?
took=$((SECONDS - started))
expect_exit 1 "$status" "limit: a file past the limit fails the run"
expect_match '^  FAIL  slow$' "$out" "limit: the timed-out file is named"
expect_match '^        timed out after 2 s; 1 checks recorded before the limit$' "$out" "limit: the detail gives the limit and the checks recorded"
expect_exit 0 "$([ "$took" -lt 20 ]; echo $?)" "limit: run.sh stops the file near the limit, not after its 30 s sleep (took ${took} s)"
port=$(cat "$sb/port" 2>/dev/null)
expect_match '^[0-9]+$' "$port" "limit: the fixture server had started"
curl -s -o /dev/null --max-time 2 "http://127.0.0.1:${port:-1}/"
expect_exit 7 "$?" "limit: the server that the file started is stopped with it"

# The shared helpers, on this OS.
h=$(mktemp -d -p "$work")
printf 'x\n' >"$h/target"
if make_link "$h/target" "$h/link"; then
  expect_exit 0 "$([ -L "$h/link" ]; echo $?)" "make_link: exit 0 means a real symlink"
else
  expect_exit 1 "$([ -e "$h/link" ]; echo $?)" "make_link: exit 1 leaves no file at the link"
  is_windows || record FAIL "make_link: a real link on this OS" "make_link failed outside Windows"
fi
if [ "$(id -u)" != 0 ]; then
  printf 'secret\n' >"$h/locked"
  if deny r "$h/locked"; then
    cat "$h/locked" >/dev/null 2>&1
    expect_exit 1 "$?" "deny r: the file cannot be read"
  else
    skip "deny r: the file cannot be read" "Git Bash reads past icacls with an admin's backup rights"
  fi
  python3 -c 'import sys; open(sys.argv[1]).read()' "$h/locked" 2>/dev/null
  expect_exit 1 "$?" "deny r: Python cannot read it either"
  allow "$h/locked"
  expect_match '^secret$' "$(cat "$h/locked" 2>&1)" "allow: the file reads again"
  deny w "$h/locked"
  python3 -c 'import sys; open(sys.argv[1], "a").write("x")' "$h/locked" 2>/dev/null
  expect_exit 1 "$?" "deny w: Python cannot write the file"
  allow "$h/locked"
fi
# command: the run.sh python3 wrapper is a function, and $! would then be a subshell.
command python3 -c 'import socket, sys
s = socket.socket(); s.bind(("127.0.0.1", 0)); s.listen()
open(sys.argv[1] + ".tmp", "w").write(str(s.getsockname()[1]))
import os; os.replace(sys.argv[1] + ".tmp", sys.argv[1])
while True: s.accept()[0].close()' "$h/port" >/dev/null 2>&1 &
server=$!
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [ -s "$h/port" ] && break; sleep 0.25; done
stop_tree "$server"
curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$(cat "$h/port")/"
expect_exit 7 "$?" "stop_tree: the server is stopped"
mkdir -p "$h/stub"
printf '#!/bin/sh\necho stub\n' >"$h/stub/gh"
narrow=$(narrow_path "$h/stub")
expect_match "^$h/stub/gh\$" "$(PATH="$narrow" command -v gh)" "narrow_path: gh is the stub"
expect_exit 0 "$(PATH="$narrow" git --version >/dev/null 2>&1; echo $?)" "narrow_path: git runs"

# A watchdog that is killed just after its fork can run run.sh's EXIT trap
# and delete $work under the next file; 20 quick runs in a row catch it.
sb=$(sandbox quick 'expect_exit 0 0 "ran"
skip "probe" "reason"')
lost=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  out=$(bash "$sb/tests/run.sh" quick 2>&1)
  case "$out" in *"No such file"*|*"0 passed, 0 failed, 0 skipped") lost=$((lost + 1)) ;; esac
done
expect_exit 0 "$lost" "20 quick runs in a row: no run lost its results"

# A multi-line detail prints whole, with each CR in sight.
sb=$(sandbox detail 'record FAIL "two lines" "$(printf "expected [a\r\nb]")"')
out=$(bash "$sb/tests/run.sh" detail 2>&1)
expect_match '^        expected \[a\\r\\nb\]$' "$out" "detail: a CR and a newline print as \\r and \\n, on one line"

# A test's own python3 -c snippet writes LF and UTF-8, whatever the OS default is.
expect_match '^a·b$' "$(python3 -c 'print("a\u00b7b")')" "python3 -c: a middle dot comes out as UTF-8"
expect_exit 1 "$(python3 -c 'print("x")' | grep -qU $'\r'; echo $?)" "python3 -c: the line ends in LF, with no CR"
