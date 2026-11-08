#!/usr/bin/env bash
# Test runner for the zuko guard scripts.
# Usage: run.sh [<name>]   -- no name runs every tests/test-*.sh
#
# Test files are sourced, not executed, so they can call the helpers below.
# Each one gets $scripts (the scripts/ directory) and records its results with
# expect_exit / expect_match / expect_no_match, or skip when Windows refuses a
# check's setup (D105). Each file has ZUKO_TEST_LIMIT seconds, 600 by
# default, and fails past it (D106).
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
scripts=$(dirname "$here")

results_file=""

# A CR or a newline in the detail is written as \r or \n, so a multi-line
# expected or got value prints whole, with each CR in sight.
record() {
  local detail="${3:-}"
  detail=${detail//$'\r'/\\r}
  detail=${detail//$'\n'/\\n}
  printf '%s\t%s\t%s\n' "$1" "$2" "$detail" >>"$results_file"
}

# A test's own `python3 -c` snippet, or `python3 -` script on stdin, reads and
# writes UTF-8 with LF, as zuko's Python does (D98). Windows Python writes
# CRLF in cp1252 by default, and $( ) keeps the CR. zuko's own scripts never
# get this prelude.
PY_LF='import sys
for _zuko_stream in (sys.stdin, sys.stdout, sys.stderr):
    _zuko_stream.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n")
'
python3() {
  if [ "${1:-}" = -c ]; then
    command python3 -c "$PY_LF$2" "${@:3}"
  elif [ "${1:-}" = - ]; then
    { printf '%s' "$PY_LF"; cat; } | command python3 - "${@:2}"
  else
    command python3 "$@"
  fi
}

expect_exit() {        # expect_exit <expected> <actual> <description>
  if [ "$2" = "$1" ]; then record PASS "$3"
  else record FAIL "$3" "expected exit $1, got $2"; fi
}

# grep reads a here-string, not a pipe: under pipefail, grep -q quitting at the
# first match kills the writer with SIGPIPE on text over 64 KB, and the
# pipeline then reports 141 instead of grep's answer.
expect_match() {       # expect_match <regex> <text> <description>
  if grep -qE -e "$1" <<<"$2"; then record PASS "$3"
  else record FAIL "$3" "nothing matched /$1/ in [${2:0:300}]"; fi
}

expect_no_match() {    # expect_no_match <regex> <text> <description>
  if grep -qE -e "$1" <<<"$2"; then record FAIL "$3" "matched /$1/ and should not have, in [${2:0:300}]"
  else record PASS "$3"; fi
}

skip() {               # skip <description> <reason>: the check did not run, and why
  record SKIP "$1" "$2"
}

is_windows() {         # is_windows: true in Git Bash on Windows
  case "$(uname -s)" in MINGW*|MSYS*) return 0 ;; esac
  return 1
}

make_link() {          # make_link <target> <link>: a real symlink, or exit 1 and no file at <link>
  if is_windows; then
    MSYS=winsymlinks:nativestrict ln -s "$1" "$2" 2>/dev/null
  else
    ln -s "$1" "$2"
  fi
  [ -L "$2" ] && return 0
  rm -f "$2"
  return 1
}

# On Windows a read is denied with icacls, which an admin's Git Bash reads
# past with backup rights, so deny r exits 1 when cat can still read the file.
# A write is denied with the read-only attribute, which os.access reads.
deny() {               # deny r|w <file>: the user can no longer read, or write, <file>
  if ! is_windows; then
    chmod "a-$1" "$2"
  elif [ "$1" = r ]; then
    icacls "$(cygpath -w "$2")" //deny "$USERNAME:(R)" >/dev/null
    ! cat "$2" >/dev/null 2>&1
  else
    attrib +R "$(cygpath -w "$2")" >/dev/null
  fi
}

allow() {              # allow <file>: undo deny
  if is_windows; then
    icacls "$(cygpath -w "$1")" //remove:d "$USERNAME" >/dev/null
    attrib -R "$(cygpath -w "$1")" >/dev/null
  else
    chmod u+rw "$1"
  fi
}

# kill alone leaves the children of a native Windows program alive, so a
# server that a shim started keeps its port; taskkill /T ends the whole tree.
stop_tree() {          # stop_tree <pid>: stop a background job and each process it started
  if is_windows && [ -r "/proc/$1/winpid" ]; then
    taskkill //F //T //PID "$(cat "/proc/$1/winpid")" >/dev/null 2>&1
  else
    kill -TERM -- "-$1" 2>/dev/null || kill "$1" 2>/dev/null
  fi
  wait "$1" 2>/dev/null
  return 0
}

# A copied git.exe cannot find its DLLs, so on Windows the PATH holds git's
# and bash's own folders, which have no gh.
narrow_path() {        # narrow_path <dir>: a PATH of <dir> and git, so gh is only a stub in <dir>
  if is_windows; then
    printf '%s:%s:%s' "$1" "$(dirname "$(command -v git)")" "$(dirname "$(command -v bash)")"
  else
    ln -sf "$(command -v git)" "$1/git"
    printf '%s' "$1"
  fi
}

native() {             # native <path>: the path as native Windows programs print it
  if is_windows; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

cr_free_lines() {      # cr_free_lines <file>: how many lines have no CR at their end
  command python3 -c 'import sys; print(sum(1 for line in open(sys.argv[1], "rb").read().split(b"\n") if not line.endswith(b"\r")))' "$1"
}

name="${1:-}"
files=()
if [ -n "$name" ]; then
  if [ ! -f "$here/test-$name.sh" ]; then
    echo "run.sh: no test file at tests/test-$name.sh. A name that matches nothing is an error, not a pass." >&2
    exit 1
  fi
  files=("$here/test-$name.sh")
else
  for candidate in "$here"/test-*.sh; do
    [ -f "$candidate" ] && files+=("$candidate")
  done
fi

if [ "${#files[@]}" -eq 0 ]; then
  echo "run.sh: no tests ran. A run that scanned nothing is not a pass." >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

total_pass=0
total_fail=0
total_skip=0
limit="${ZUKO_TEST_LIMIT:-600}"

for file in "${files[@]}"; do
  base=$(basename "$file" .sh)
  base=${base#test-}
  results_file="$work/$base.results"
  : >"$results_file"

  # Job control gives the file its own process group, so stop_tree ends the
  # file and every server that it started. The watchdog ends by itself once
  # the file is gone: a child killed just after its fork can still run the
  # EXIT trap above and remove $work.
  set -m
  ( . "$file" ) </dev/null &
  job=$!
  set +m
  (
    ticks=$((limit * 5))
    while [ "$ticks" -gt 0 ] && kill -0 "$job" 2>/dev/null; do sleep 0.2; ticks=$((ticks - 1)); done
    # taskkill misses a Git Bash child such as sleep; the file's own process
    # group has it.
    if [ "$ticks" -eq 0 ]; then
      : >"$results_file.late"
      stop_tree "$job"
      kill -TERM -- "-$job" 2>/dev/null
    fi
  ) >/dev/null 2>&1 </dev/null &
  dog=$!
  wait "$job"
  status=$?
  wait "$dog"
  if [ -f "$results_file.late" ]; then
    record FAIL "$base" "timed out after $limit s; $(grep -c . "$results_file" || true) checks recorded before the limit"
  elif [ "$status" -ne 0 ]; then
    record FAIL "$base" "the test file exited non-zero partway through"
  fi

  if [ ! -s "$results_file" ]; then
    record FAIL "$base" "the test file recorded nothing"
  fi

  passed=$(grep -c '^PASS' "$results_file" || true)
  failed=$(grep -c '^FAIL' "$results_file" || true)
  skipped=$(grep -c '^SKIP' "$results_file" || true)
  total_pass=$((total_pass + passed))
  total_fail=$((total_fail + failed))
  total_skip=$((total_skip + skipped))

  if [ "$failed" -ne 0 ]; then
    printf '%s\n' "$base"
  elif [ "$skipped" -ne 0 ]; then
    printf '%-19s%3s passed, %s skipped\n' "$base" "$passed" "$skipped"
  else
    printf '%-19s%3s passed\n' "$base" "$passed"
  fi
  for shown in FAIL SKIP; do
    while IFS=$'\t' read -r status description detail; do
      [ "$status" = "$shown" ] || continue
      printf '  %s  %s\n' "$shown" "$description"
      [ -n "$detail" ] && printf '        %s\n' "$detail"
    done <"$results_file"
  done
done

printf '%-19s%3s passed, %s failed, %s skipped\n' "" "$total_pass" "$total_fail" "$total_skip"
[ "$total_fail" -eq 0 ] || exit 1
exit 0
