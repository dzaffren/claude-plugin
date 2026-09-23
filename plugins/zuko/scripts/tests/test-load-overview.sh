# scripts/load-overview.sh -- the SessionStart overview loader, one test per state.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

work=$(mktemp -d)

# write_overview <dir> <status-line> <total-lines>: a real file of that length,
# the status line (if any) second, numbered body lines after it.
write_overview() {
  local i=2
  {
    echo "# invoice-cli"
    if [ -n "$2" ]; then echo "$2"; i=3; fi
    while [ "$i" -le "$3" ]; do echo "line $i"; i=$((i + 1)); done
  } >"$1/OVERVIEW.md"
}

load() {        # load <dir>; sets $load_out $load_status
  load_out=$(cd "$1" && CLAUDE_PROJECT_DIR="$1" bash "$scripts/load-overview.sh" 2>&1)
  load_status=$?
}

line_count() { printf '%s\n' "$1" | wc -l | tr -d ' '; }

active='**Status:** Active · **Updated:** 2026-09-24 by /ship export-csv'
draft='**Status:** Draft · **Updated:** 2026-09-24 by /spec export-csv'

# 1. Active, 96 lines: header then the whole file.
dir=$(mktemp -d -p "$work"); write_overview "$dir" "$active" 96; load "$dir"
expect_exit 0 "$load_status" "active 96: exits 0"
expect_match '^Project overview \(OVERVIEW\.md\):$' "$load_out" "active 96: header line"
expect_match '^line 96$' "$load_out" "active 96: last line loaded"
expect_no_match 'Warning|Draft' "$load_out" "active 96: no warning, no Draft mark"
expect_match '^97$' "$(line_count "$load_out")" "active 96: header plus 96 lines"

# 2. Active, 180 lines: header, first 150, then a warning with the real count.
dir=$(mktemp -d -p "$work"); write_overview "$dir" "$active" 180; load "$dir"
expect_exit 0 "$load_status" "active 180: exits 0"
expect_match '^Project overview \(OVERVIEW\.md\):$' "$load_out" "active 180: header line"
expect_match '^line 150$' "$load_out" "active 180: line 150 loaded"
expect_no_match '^line 151$' "$load_out" "active 180: line 151 not loaded"
expect_match '^Warning: OVERVIEW\.md is 180 lines; loaded the first 150\. Trim it to 150\.$' \
  "$(printf '%s\n' "$load_out" | tail -1)" "active 180: last line warns with the real length"
expect_match '^152$' "$(line_count "$load_out")" "active 180: header, 150 lines, warning"

# 3. Draft: marked not yet confirmed, then the file; the cap applies too.
dir=$(mktemp -d -p "$work"); write_overview "$dir" "$draft" 96; load "$dir"
expect_exit 0 "$load_status" "draft: exits 0"
expect_match '^Project overview \(OVERVIEW\.md\) — Draft — not yet confirmed:$' "$load_out" "draft: header marks Draft"
expect_match '^line 96$' "$load_out" "draft: file loaded"
dir=$(mktemp -d -p "$work"); write_overview "$dir" "$draft" 180; load "$dir"
expect_no_match '^line 151$' "$load_out" "draft 180: capped at 150"
expect_match '^Warning: OVERVIEW\.md is 180 lines' "$load_out" "draft 180: warns"

# 4. Missing: exactly one line.
dir=$(mktemp -d -p "$work"); load "$dir"
expect_exit 0 "$load_status" "missing: exits 0"
expect_match '^No OVERVIEW\.md — the next zuko stage will onboard this repo\.$' "$load_out" "missing: the onboard hint"
expect_match '^1$' "$(line_count "$load_out")" "missing: exactly one line"

# 5. No Status line: said so, then loaded as Draft.
dir=$(mktemp -d -p "$work"); write_overview "$dir" "" 40; load "$dir"
expect_exit 0 "$load_status" "no status: exits 0"
expect_match '^OVERVIEW\.md has no Status line — loaded as Draft\.$' \
  "$(printf '%s\n' "$load_out" | head -1)" "no status: first line says so"
expect_match '^Project overview \(OVERVIEW\.md\) — Draft — not yet confirmed:$' "$load_out" "no status: Draft header"
expect_match '^line 40$' "$load_out" "no status: file loaded"

# 6. Unreadable: never blocks the session. (root reads anything, so skip there.)
if [ "$(id -u)" != 0 ]; then
  dir=$(mktemp -d -p "$work"); write_overview "$dir" "$active" 10
  chmod a-r "$dir/OVERVIEW.md"; load "$dir"; chmod u+r "$dir/OVERVIEW.md"
  expect_exit 0 "$load_status" "unreadable: exits 0"
  expect_match 'has no Status line — loaded as Draft' "$load_out" "unreadable: reported as no Status line"
fi

# 7. hooks.json: valid JSON, and the loader runs after load-learnings.sh.
order=$(python3 -c '
import json, sys
groups = json.load(open(sys.argv[1]))["hooks"]["SessionStart"]
cmds = [h["command"] for g in groups for h in g["hooks"]]
l = [i for i, c in enumerate(cmds) if "load-learnings.sh" in c]
o = [i for i, c in enumerate(cmds) if "load-overview.sh" in c]
print("ok" if l and o and o[0] > l[0] else "bad: %s" % cmds)
' "$scripts/../hooks/hooks.json" 2>&1)
expect_match '^ok$' "$order" "hooks.json: valid, load-overview.sh after load-learnings.sh"

# 8. 151 lines with no newline after the last: that line still counts.
dir=$(mktemp -d -p "$work"); write_overview "$dir" "$active" 150; printf 'line 151' >>"$dir/OVERVIEW.md"; load "$dir"
expect_match '^Warning: OVERVIEW\.md is 151 lines; loaded the first 150\. Trim it to 150\.$' "$load_out" "no final newline: the last line is counted and warned about"

# 9. A symlink is never followed out of the repo.
dir=$(mktemp -d -p "$work"); outside=$(mktemp -d -p "$work")
printf '%s\n' "$active" "SECRET-OUTSIDE-THE-REPO" >"$outside/target.md"
ln -s "$outside/target.md" "$dir/OVERVIEW.md"; load "$dir"
expect_exit 0 "$load_status" "symlink: exits 0"
expect_match '^OVERVIEW\.md is a symlink — not loaded\.$' "$load_out" "symlink: says it was not loaded"
expect_no_match 'SECRET-OUTSIDE-THE-REPO' "$load_out" "symlink: the target's content never reaches context"

# 10. The cap is bytes as well as lines.
dir=$(mktemp -d -p "$work")
{ echo "$active"; head -c 300000 /dev/zero | tr '\0' x; echo; } >"$dir/OVERVIEW.md"; load "$dir"
expect_exit 0 "$load_status" "one huge line: exits 0"
expect_match '^Warning: OVERVIEW\.md is over 16384 bytes; loaded the first 16384\. Trim it\.$' "$load_out" "one huge line: warns about the byte cap"
bytes=$(printf '%s' "$load_out" | wc -c | tr -d ' ')
[ "$bytes" -lt 17000 ] && ok=yes || ok="no: $bytes bytes"
expect_match '^yes$' "$ok" "one huge line: output stays under 17000 bytes"

rm -rf "$work"
