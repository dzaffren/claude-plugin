# scripts/lib/decisions.py and scripts/load-decisions.sh -- the parser, the
# session titles, and every outcome of the integrity check.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

work=$(mktemp -d)
decisions="$scripts/lib/decisions.py"

header() {   # header <file>: the title line and the append-only paragraph
  cat >"$1" <<'HEAD'
# Decisions

Append-only. A changed decision is a new entry that supersedes the old one; only an
old entry's Status line ever changes.
HEAD
}

entry() {    # entry <file> <n> <title> [status] [supersedes]
  {
    echo ""
    echo "## D$2 · 2026-09-24 · $3"
    echo ""
    echo "Why: reason number $2, with a number: 40 seconds."
    echo "Rejected: option-$2 (costs more), other-$2 (slower)."
    [ -n "${5:-}" ] && echo "Supersedes: D$5"
    echo "Source: specs/slice-$2.md"
    echo "Status: ${4:-active}"
  } >>"$1"
}

new_repo() {   # new_repo; prints a repo on a branch whose base holds D1..D7
  local dir i
  dir=$(mktemp -d -p "$work")
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email t@example.com
  git -C "$dir" config user.name Tester
  header "$dir/DECISIONS.md"
  for i in 1 2 3 4 5 6; do entry "$dir/DECISIONS.md" "$i" "Choice $i"; done
  entry "$dir/DECISIONS.md" 7 "Use Postgres, not SQLite"
  git -C "$dir" add -A
  git -C "$dir" commit -q --no-verify -m "docs: record D1 to D7"
  git -C "$dir" checkout -q -b feat/offline-mode
  printf '%s' "$dir"
}

check() {      # check <repo> [base]; sets $check_out $check_status
  local base
  base=${2:-$(git -C "$1" merge-base HEAD main)}
  check_out=$(python3 "$decisions" check "$1" --base "$base" --label main 2>&1)
  check_status=$?
}

load() {       # load <dir>; sets $load_out $load_status
  load_out=$(cd "$1" && CLAUDE_PROJECT_DIR="$1" bash "$scripts/load-decisions.sh" 2>&1)
  load_status=$?
}

# Rewrite <file> through an awk program, in place.
rewrite() {    # rewrite <file> <awk program>
  awk "$2" "$1" >"$1.tmp" && mv "$1.tmp" "$1"
}

# Supersede D7 with D8 the way the reference says: flip only D7's Status line.
supersede_d7() {   # supersede_d7 <repo>
  rewrite "$1/DECISIONS.md" '
    /^## D/ { in7 = ($0 ~ /^## D7 · /) }
    in7 && /^Status: active$/ { print "Status: superseded by D8"; next }
    { print }'
  entry "$1/DECISIONS.md" 8 "Postgres on the server, SQLite for the laptop cache" active 7
}

# --- The session loader ---

# 1. Twelve entries, two superseded: ten title lines, nothing else.
dir=$(mktemp -d -p "$work")
header "$dir/DECISIONS.md"
for i in 1 2; do entry "$dir/DECISIONS.md" "$i" "Choice $i"; done
entry "$dir/DECISIONS.md" 3 "Old choice 3" "superseded by D9"
for i in 4 5 6; do entry "$dir/DECISIONS.md" "$i" "Choice $i"; done
entry "$dir/DECISIONS.md" 7 "Use Postgres, not SQLite" "superseded by D12"
entry "$dir/DECISIONS.md" 8 "Choice 8"
entry "$dir/DECISIONS.md" 9 "New choice 3" active 3
entry "$dir/DECISIONS.md" 10 "Choice 10"
entry "$dir/DECISIONS.md" 11 "Choice 11"
entry "$dir/DECISIONS.md" 12 "Postgres on the server, SQLite for the laptop cache" active 7
load "$dir"
expect_exit 0 "$load_status" "loader: exits 0"
expect_match "^Active decisions \(DECISIONS\.md\) — check before proposing; supersede, don't contradict:$" \
  "$load_out" "loader: header line"
expect_match '^11$' "$(printf '%s\n' "$load_out" | wc -l | tr -d ' ')" "loader: header plus 10 active titles"
expect_match '^  D12  Postgres on the server, SQLite for the laptop cache$' "$load_out" "loader: D12 listed with its title"
expect_match '^  D2   Choice 2$' "$load_out" "loader: IDs padded to one column"
expect_no_match 'D7 |D3 ' "$load_out" "loader: superseded entries are not listed"
expect_no_match 'Why:|Rejected:|Source:|Status:|Supersedes:' "$load_out" "loader: no entry bodies"

# 2. No file: silent.
dir=$(mktemp -d -p "$work"); load "$dir"
expect_exit 0 "$load_status" "loader no file: exits 0"
expect_match '^$' "$load_out" "loader no file: prints nothing"

# 3. The title only, as onboarding writes it.
dir=$(mktemp -d -p "$work"); header "$dir/DECISIONS.md"; load "$dir"
expect_exit 0 "$load_status" "loader empty: exits 0"
expect_match '^DECISIONS\.md has no entries yet\.$' "$load_out" "loader empty: says so"

# 4. A symlink could point anywhere; never follow one into context.
dir=$(mktemp -d -p "$work"); header "$work/elsewhere.md"; ln -s "$work/elsewhere.md" "$dir/DECISIONS.md"; load "$dir"
expect_exit 0 "$load_status" "loader symlink: exits 0"
expect_match '^DECISIONS\.md is a symlink — not loaded\.$' "$load_out" "loader symlink: not loaded"

# 5. Headings inside a fence are examples, not entries.
dir=$(mktemp -d -p "$work"); header "$dir/DECISIONS.md"
printf '\n```\n## D99 · 2026-09-24 · An example\n```\n' >>"$dir/DECISIONS.md"
load "$dir"
expect_match '^DECISIONS\.md has no entries yet\.$' "$load_out" "loader fence: a fenced heading is not an entry"

# --- active: the full entries, for the reviewer ---

repo=$(new_repo); supersede_d7 "$repo"
active_out=$(python3 "$decisions" active "$repo" 2>&1)
expect_exit 0 "$?" "active: exits 0"
expect_match '^## D8 · 2026-09-24 · Postgres on the server, SQLite for the laptop cache$' "$active_out" "active: D8 heading printed"
expect_match '^Rejected: option-8 \(costs more\), other-8 \(slower\)\.$' "$active_out" "active: bodies printed"
expect_no_match '^## D7 ' "$active_out" "active: superseded D7 left out"

# The reviewer skips its Decisions lens when the repo has no DECISIONS.md.
dir=$(mktemp -d -p "$work")
active_out=$(python3 "$decisions" active "$dir" 2>&1)
expect_exit 0 "$?" "active no file: exits 0"
expect_match '^$' "$active_out" "active no file: prints nothing"

# --- check: the integrity rule and the structure rules ---

# 6. Supersede done right: D8 appended, only D7's Status line changed.
repo=$(new_repo); supersede_d7 "$repo"; check "$repo"
expect_exit 0 "$check_status" "check supersede: passes"
expect_match '^Decisions: 8 entries checked against main$' "$check_out" "check supersede: prints the scope line"

# 7. An edited Why line in a recorded entry.
repo=$(new_repo)
rewrite "$repo/DECISIONS.md" '{ sub(/^Why: reason number 3,/, "Why: a different reason 3,"); print }'
check "$repo"
expect_exit 1 "$check_status" "check edited: fails"
expect_match '^DECISIONS\.md  D3 changed after it was recorded — only its Status line may change; supersede it with a new entry$' \
  "$check_out" "check edited: names D3 and the fix"
expect_no_match 'D[124567] ' "$check_out" "check edited: names no other entry"

# 8. A recorded entry deleted.
repo=$(new_repo)
rewrite "$repo/DECISIONS.md" '/^## D5 · /{skip=1} /^## D6 · /{skip=0} !skip'
check "$repo"
expect_exit 1 "$check_status" "check removed: fails"
expect_match '^DECISIONS\.md  D5 was removed after it was recorded — supersede it with a new entry instead$' \
  "$check_out" "check removed: names D5"

# 9. A formatter re-wraps an old Why line: not an edit.
repo=$(new_repo)
rewrite "$repo/DECISIONS.md" '/^Why: reason number 3, with a number: 40 seconds\.$/ { print "Why: reason number 3,"; print "    with a number:   40 seconds."; next } { print }'
expect_match '^    with a number:   40 seconds\.$' "$(cat "$repo/DECISIONS.md")" "check rewrap: the fixture re-wrapped D3"
check "$repo"
expect_exit 0 "$check_status" "check rewrap: passes"

# 10. The same number twice.
repo=$(new_repo); entry "$repo/DECISIONS.md" 8 "One"; entry "$repo/DECISIONS.md" 8 "Two"; check "$repo"
expect_exit 1 "$check_status" "check duplicate: fails"
expect_match '^DECISIONS\.md  D8 appears twice$' "$check_out" "check duplicate: names D8"

# 11. A supersede the old entry does not acknowledge.
repo=$(new_repo); entry "$repo/DECISIONS.md" 8 "Replaces D7" active 7; check "$repo"
expect_exit 1 "$check_status" "check dangling supersede: fails"
expect_match '^DECISIONS\.md  D8 supersedes D7, but D7 does not say "superseded by D8"$' "$check_out" "check dangling supersede: names both"

# 12. A status that points at an entry which never says it supersedes.
repo=$(new_repo)
rewrite "$repo/DECISIONS.md" '/^## D/ { in1 = ($0 ~ /^## D1 · /) } in1 && /^Status: active$/ { print "Status: superseded by D8"; next } { print }'
entry "$repo/DECISIONS.md" 8 "Unrelated"
check "$repo"
expect_exit 1 "$check_status" "check one-sided status: fails"
expect_match '^DECISIONS\.md  D1 says "superseded by D8", but D8 does not say "Supersedes: D1"$' "$check_out" "check one-sided status: names both"

# 13. Supersedes an entry that does not exist.
repo=$(new_repo); entry "$repo/DECISIONS.md" 8 "Replaces nothing" active 40; check "$repo"
expect_exit 1 "$check_status" "check missing target: fails"
expect_match '^DECISIONS\.md  D8 supersedes D40, but there is no D40$' "$check_out" "check missing target: names D40"

# 14. No Rejected line.
repo=$(new_repo); entry "$repo/DECISIONS.md" 8 "Nothing rejected"
rewrite "$repo/DECISIONS.md" '!/^Rejected: option-8/'
check "$repo"
expect_exit 1 "$check_status" "check no Rejected: fails"
expect_match '^DECISIONS\.md  D8 has no Rejected line — a choice with nothing rejected is not an entry$' "$check_out" "check no Rejected: says why"

# 15. The other required lines.
repo=$(new_repo); entry "$repo/DECISIONS.md" 8 "Bare"
rewrite "$repo/DECISIONS.md" '!/^Why: reason number 8/ && !/^Source: specs\/slice-8/'
check "$repo"
expect_exit 1 "$check_status" "check no Why or Source: fails"
expect_match '^DECISIONS\.md  D8 has no Why line$' "$check_out" "check no Why: named"
expect_match '^DECISIONS\.md  D8 has no Source line$' "$check_out" "check no Source: named"

# 16. A Status that is neither active nor superseded, and one not last.
repo=$(new_repo); entry "$repo/DECISIONS.md" 8 "Odd" "maybe"; check "$repo"
expect_exit 1 "$check_status" "check bad status: fails"
expect_match "^DECISIONS\.md  D8 Status is 'maybe' — it must be 'active' or 'superseded by D<n>'$" "$check_out" "check bad status: named"
repo=$(new_repo); entry "$repo/DECISIONS.md" 8 "Late"; echo "Source: specs/moved.md" >>"$repo/DECISIONS.md"; check "$repo"
expect_match '^DECISIONS\.md  D8 Status is not the last line$' "$check_out" "check status not last: named"

# 17. Numbers go up.
repo=$(new_repo); entry "$repo/DECISIONS.md" 9 "Nine"; entry "$repo/DECISIONS.md" 8 "Eight"; check "$repo"
expect_exit 1 "$check_status" "check order: fails"
expect_match '^DECISIONS\.md  D8 comes after D9 — number each entry one more than the highest$' "$check_out" "check order: named"

# 18. A heading that is not an entry heading.
repo=$(new_repo); printf '\n## D8 - 2026-09-24 - Wrong separators\n\nWhy: x\n' >>"$repo/DECISIONS.md"; check "$repo"
expect_exit 1 "$check_status" "check bad heading: fails"
expect_match "^DECISIONS\.md  heading '## D8 - 2026-09-24 - Wrong separators' is not '## D<n> · <YYYY-MM-DD> · <title>'$" "$check_out" "check bad heading: quoted"

# 19. No DECISIONS.md at the base: every entry is new.
repo=$(mktemp -d -p "$work")
git -C "$repo" init -q -b main; git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name Tester
echo x >"$repo/work.txt"; git -C "$repo" add -A; git -C "$repo" commit -q --no-verify -m "chore: start"
git -C "$repo" checkout -q -b feat/first
header "$repo/DECISIONS.md"; entry "$repo/DECISIONS.md" 1 "First"
check "$repo"
expect_exit 0 "$check_status" "check new file: passes"
expect_match '^Decisions: 1 entries checked against main$' "$check_out" "check new file: scope line"

# 20. No DECISIONS.md on the branch.
mv "$repo/DECISIONS.md" "$work/moved-away.md"; check "$repo"
expect_exit 1 "$check_status" "check missing file: fails"
expect_match '^DECISIONS\.md  missing — onboarding creates it$' "$check_out" "check missing file: says who creates it"

# 21. The file exists with no entries: the scope line still reports what it read.
header "$repo/DECISIONS.md"; check "$repo"
expect_exit 0 "$check_status" "check empty file: passes"
expect_match '^Decisions: 0 entries checked against main$' "$check_out" "check empty file: scope line says 0"

# 22. A base that does not resolve is an error, never a pass.
check "$repo" deadbeefdeadbeef
expect_exit 2 "$check_status" "check bad base: exits 2"
expect_match "^decisions\.py: base 'deadbeefdeadbeef' is not a commit$" "$check_out" "check bad base: names the ref"

rm -rf "$work"
