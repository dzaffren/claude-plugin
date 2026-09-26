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
