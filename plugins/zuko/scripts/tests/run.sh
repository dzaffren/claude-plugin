#!/usr/bin/env bash
# Test runner for the zuko guard scripts.
# Usage: run.sh [<name>]   -- no name runs every tests/test-*.sh
#
# Test files are sourced, not executed, so they can call the helpers below.
# Each one gets $scripts (the scripts/ directory) and records its results with
# expect_exit / expect_match / expect_no_match.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
scripts=$(dirname "$here")

results_file=""

record() { printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >>"$results_file"; }

expect_exit() {        # expect_exit <expected> <actual> <description>
  if [ "$2" = "$1" ]; then record PASS "$3"
  else record FAIL "$3" "expected exit $1, got $2"; fi
}

expect_match() {       # expect_match <regex> <text> <description>
  if printf '%s\n' "$2" | grep -qE "$1"; then record PASS "$3"
  else record FAIL "$3" "nothing matched /$1/"; fi
}

expect_no_match() {    # expect_no_match <regex> <text> <description>
  if printf '%s\n' "$2" | grep -qE "$1"; then record FAIL "$3" "matched /$1/ and should not have"
  else record PASS "$3"; fi
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

for file in "${files[@]}"; do
  base=$(basename "$file" .sh)
  base=${base#test-}
  results_file="$work/$base.results"
  : >"$results_file"

  ( . "$file" ) || record FAIL "$base" "the test file exited non-zero partway through"

  if [ ! -s "$results_file" ]; then
    record FAIL "$base" "the test file recorded nothing"
  fi

  passed=$(grep -c '^PASS' "$results_file" || true)
  failed=$(grep -c '^FAIL' "$results_file" || true)
  total_pass=$((total_pass + passed))
  total_fail=$((total_fail + failed))

  if [ "$failed" -eq 0 ]; then
    printf '%-19s%3s passed\n' "$base" "$passed"
  else
    printf '%s\n' "$base"
    while IFS=$'\t' read -r status description detail; do
      [ "$status" = "FAIL" ] || continue
      printf '  FAIL  %s\n' "$description"
      [ -n "$detail" ] && printf '        %s\n' "$detail"
    done <"$results_file"
  fi
done

printf '%-19s%3s passed, %s failed\n' "" "$total_pass" "$total_fail"
[ "$total_fail" -eq 0 ] || exit 1
exit 0
