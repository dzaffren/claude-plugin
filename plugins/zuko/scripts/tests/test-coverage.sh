# scripts/lib/coverage.py, through release.py pick and cut -- the coverage
# ledger: which files are units, the old files pick gives, the marks cut
# writes, and the ledgers cut refuses.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

work=$(mktemp -d -p "$work")
release="$scripts/lib/release.py"

# A stand-in for gh: no CI checks and no release yet.
mkdir -p "$work/bin"
cat >"$work/bin/gh" <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "api "*/check-runs*) echo '{"total_count": 0, "check_runs": []}' ;;
  "api "*/status*) echo '{"state": "pending", "total_count": 0, "statuses": []}' ;;
  "release view") echo "release not found" >&2; exit 1 ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"

run() {        # run <args...>; sets $out $status
  out=$(python3 "$release" "$@" 2>&1)
  status=$?
  out=${out//$'\r'/}
}

last_line() {  # last_line <text>
  printf '%s\n' "$1" | tail -n 1
}

snapshot() {   # snapshot <repo>: every file's bytes, the status and the tags, as one hash
  { git -C "$1" status --porcelain; git -C "$1" tag; git -C "$1" rev-parse HEAD
    find "$1" -path "$1/.git" -prune -o -type f -print | sort | xargs cat; } | cksum
}

commit() {     # commit <message>: stage everything in $repo and commit
  git -C "$repo" add -A
  git -C "$repo" commit -q --no-verify -m "$1"
}

unreleased() { # unreleased <line>: a changelog line under [Unreleased], as /ship writes it
  awk -v add="$1" '{ print } $0 == "## [Unreleased]" { print "\n### Added\n\n- " add }' "$repo/CHANGELOG.md" >"$work/CHANGELOG.md"
  mv "$work/CHANGELOG.md" "$repo/CHANGELOG.md"
}

released() {   # released <version>: commit what cut wrote and tag it
  commit "chore(release): v$1"
  git -C "$repo" tag -a "v$1" -m "v$1"
}

# invoice-cli on main, tagged v1.4.2, with the files that are units and some
# that are not: a tests folder, a test folder, docs/, and .md files at the root.
scratch() {    # scratch <dir> <unit>...: sets $repo; check.sh is always a unit
  local unit
  repo=$1
  shift
  mkdir -p "$repo"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email t@example.com
  git -C "$repo" config user.name Tester
  git -C "$repo" remote add origin https://github.com/acme/invoice-cli.git
  cat >"$repo/OVERVIEW.md" <<'OVERVIEW'
# invoice-cli

**Status:** Active · **Updated:** 2026-09-25 by /ship export-csv

Turns a folder of supplier invoices into one ledger CSV.

## Run it

| Task    | Command            |
| ------- | ------------------ |
| install | `pip install -e .` |
| test    | `sh check.sh`      |
OVERVIEW
  printf 'exit 0\n' >"$repo/check.sh"
  printf '# Changelog\n\n## [Unreleased]\n\n## [1.4.2] - 2026-08-01\n\n### Fixed\n\n- Totals round to the cent.\n' >"$repo/CHANGELOG.md"
  printf '# Decisions\n\n## D1 · 2026-09-24 · Choice 1\n\nWhy: reason 1.\nRejected: option-1 (costs more).\nSource: specs/slice-1.md\nStatus: active\n' >"$repo/DECISIONS.md"
  printf '# invoice-cli\n' >"$repo/README.md"
  mkdir -p "$repo/tests" "$repo/lib/test" "$repo/docs"
  printf 'def test_total(): pass\n' >"$repo/tests/test_total.py"
  printf 'def helper(): pass\n' >"$repo/lib/test/helper.py"
  printf '# Notes\n' >"$repo/docs/notes.md"
  for unit in "$@"; do
    mkdir -p "$(dirname "$repo/$unit")"
    printf '%s\n' "$unit" >"$repo/$unit"
  done
  commit "chore: release 1.4.2"
  git -C "$repo" tag -a v1.4.2 -m v1.4.2
}

pass_report() {  # pass_report <version> <lead row or ""> <file>...: a pass report with those Files checked
  local file version=$1 lead=$2
  shift 2
  file=$(mktemp -p "$work")
  {
    printf '# Pentest v%s\n\n**Result:** pass\n**Mode:** code-level\n' "$version"
    printf '**Range:** v1.4.2..a1b2c3d (1 commit)\n**Date:** 2026-10-02\n\n## Findings\n\n'
    printf '| ID | Severity | Category | Where | Description |\n| -- | -------- | -------- | ----- | ----------- |\n'
    printf '\n## Needs validation\n\n| ID | Category | Where | Description | Unknown |\n| -- | -------- | ----- | ----------- | ------- |\n'
    [ -z "$lead" ] || printf '%s\n' "$lead"
    printf '\n## Assessed\n\n- A05:2025 Injection — 1 call\n\n## Not assessed\n\n- A01:2025 Broken Access Control — needs a server\n'
    printf '\n## Files checked\n\n'
    printf -- '- %s\n' "$@"
  } >"$file"
  printf '%s' "$file"
}

old_files() {  # old_files <width> <mark> <path>...: pick's lines for those paths, each padded to <width>
  local width=$1 mark=$2 path
  shift 2
  for path in "$@"; do printf "  %-${width}s%s\n" "$path" "$mark"; done
}

has_row() {    # has_row <path> <mark>: exit 0 when the ledger in $repo has exactly that row
  grep -qxF -e "| $1 | $2 |" "$repo/docs/security/coverage.md"
}

modules=()
for n in $(seq -w 1 30); do modules+=("lib/m$n.py"); done

# 1. The first release with a ledger: none yet. pick gives the first 10 units
# outside the range, in path order. cut marks the 3 range files and those 10,
# and starts the ledger.
scratch "$work/first" "${modules[@]}" lib/notes.md
printf 'changed\n' >>"$repo/lib/m05.py"
printf 'changed\n' >>"$repo/lib/m12.py"
printf 'new\n' >"$repo/lib/new.py"
unreleased "Export one CSV for each supplier."
commit "feat(lib): one csv per supplier"
before=$(snapshot "$repo")
run pick "$repo"
expect_exit 0 "$status" "first pick: exits 0"
first_ten=(check.sh lib/m01.py lib/m02.py lib/m03.py lib/m04.py lib/m06.py lib/m07.py lib/m08.py lib/m09.py lib/m10.py)
expected="Old files  10 of 30 not checked · no ledger yet, cut starts one
$(old_files 12 unchecked "${first_ten[@]}")"
[ "$out" = "$expected" ]
expect_exit 0 "$?" "first pick: the first 10 units outside the range, in path order (got: $out)"
expect_match "^$before\$" "$(snapshot "$repo")" "first pick: writes nothing"

run cut "$repo" --version 1.5.0 --date 2026-10-02 \
  --pentest "$(pass_report 1.5.0 "" lib/m05.py lib/m12.py lib/new.py "${first_ten[@]}")"
expect_exit 0 "$status" "first cut: exits 0 (got: $(last_line "$out"))"
expect_match '^Coverage   13 of 33 files checked by a pentest · 20 not checked · ledger started$' "$(last_line "$out")" "first cut: the Coverage line says the ledger started"
expect_match '^  docs/security/coverage\.md +coverage ledger, 13 of 33 checked$' "$out" "first cut: lists the ledger it wrote"
expect_match '^docs/security/coverage\.md$' "$(cat "$repo/.git/zuko-release")" "first cut: the marker names the ledger"
{
  printf '# Coverage\n\n**Updated:** v1.5.0 · 2026-10-02\n'
  printf '**Units:** 33 · **Checked:** 13 · **Lead:** 0 · **Not checked:** 20\n\n'
  printf '| File | Mark |\n| ---- | ---- |\n'
  for unit in check.sh "${modules[@]}" lib/new.py lib/notes.md; do
    case " lib/m05.py lib/m12.py lib/new.py ${first_ten[*]} " in
      *" $unit "*) printf '| %s | v1.5.0 |\n' "$unit" ;;
      *) printf '| %s | unchecked |\n' "$unit" ;;
    esac
  done
} >"$work/expected"
cmp -s "$repo/docs/security/coverage.md" "$work/expected"
expect_exit 0 "$?" "first cut: the ledger, byte for byte: every unit sorted by path, no tests, docs or root .md"

# 2. The next release goes on from where the first stopped: it reads the
# ledger the first one committed, and the range changes 2 files that v1.5.0
# checked.
released 1.5.0
printf 'changed again\n' >>"$repo/lib/m05.py"
printf 'changed\n' >>"$repo/lib/m06.py"
unreleased "Name the supplier in each row."
commit "feat(lib): name the supplier"
run pick "$repo"
expect_exit 0 "$status" "second pick: exits 0"
next_ten=(lib/m11.py lib/m13.py lib/m14.py lib/m15.py lib/m16.py lib/m17.py lib/m18.py lib/m19.py lib/m20.py lib/m21.py)
expected="Old files  10 of 20 not checked · docs/security/coverage.md
$(old_files 12 unchecked "${next_ten[@]}")"
[ "$out" = "$expected" ]
expect_exit 0 "$?" "second pick: the next 10 unchecked units in path order (got: $out)"
run cut "$repo" --version 1.6.0 --date 2026-10-09 \
  --pentest "$(pass_report 1.6.0 "" lib/m05.py lib/m06.py "${next_ten[@]}")"
expect_exit 0 "$status" "second cut: exits 0 (got: $(last_line "$out"))"
expect_match '^Coverage   23 of 33 files checked by a pentest · 10 not checked$' "$(last_line "$out")" "second cut: the counts drop by 10, and the ledger is not new"
ledger_text=$(cat "$repo/docs/security/coverage.md")
expect_match '^\*\*Updated:\*\* v1\.6\.0 · 2026-10-09$' "$ledger_text" "second cut: the ledger names the release"
expect_match '^\*\*Units:\*\* 33 · \*\*Checked:\*\* 23 · \*\*Lead:\*\* 0 · \*\*Not checked:\*\* 10$' "$ledger_text" "second cut: the header counts"
for unit in lib/m05.py lib/m06.py lib/m11.py lib/m21.py; do
  has_row "$unit" v1.6.0
  expect_exit 0 "$?" "second cut: $unit is marked v1.6.0"
done
for unit in lib/m01.py lib/m12.py lib/new.py; do
  has_row "$unit" v1.5.0
  expect_exit 0 "$?" "second cut: $unit keeps v1.5.0"
done
has_row lib/m22.py unchecked
expect_exit 0 "$?" "second cut: lib/m22.py stays unchecked"

# 3. A release without a pentest puts the units its range changed back to
# unchecked, as "reset in". The next pick lists them before the units no run
# has checked.
released 1.6.0
printf 'changed\n' >>"$repo/lib/m01.py"
printf 'changed\n' >>"$repo/lib/m22.py"
unreleased "Round each row to the cent."
commit "fix(lib): round each row"
run cut "$repo" --version 1.7.0 --date 2026-10-16 --no-pentest "classifier stopped the run"
expect_exit 0 "$status" "skipped cut: exits 0 (got: $(last_line "$out"))"
expect_match '^Coverage   22 of 33 files checked by a pentest · 11 not checked$' "$(last_line "$out")" "skipped cut: the Coverage line"
has_row lib/m01.py "reset in v1.7.0"
expect_exit 0 "$?" "skipped cut: a checked unit in the range is reset"
has_row lib/m22.py "reset in v1.7.0"
expect_exit 0 "$?" "skipped cut: an unchecked unit in the range is reset"
has_row lib/m02.py v1.5.0
expect_exit 0 "$?" "skipped cut: a unit outside the range keeps its mark"
released 1.7.0
printf '# Notes\n\nMore.\n' >"$repo/docs/notes.md"
unreleased "Explain the rounding."
commit "feat(docs): explain the rounding"
run pick "$repo"
expect_exit 0 "$status" "pick after a skip: exits 0"
expected="Old files  10 of 11 not checked · docs/security/coverage.md
$(old_files 12 "reset in v1.7.0" lib/m01.py lib/m22.py)
$(old_files 12 unchecked lib/m23.py lib/m24.py lib/m25.py lib/m26.py lib/m27.py lib/m28.py lib/m29.py lib/m30.py)"
[ "$out" = "$expected" ]
expect_exit 0 "$?" "pick after a skip: the reset units come before the unchecked ones (got: $out)"

# 4. A file with an open lead is marked "lead in", which is not checked, and
# the next pick lists it first. A later pentest that checks it with no lead
# marks it checked. A range file that pentest did not check goes back to
# unchecked.
scratch "$work/lead" invoice_cli/cli.py invoice_cli/export.py invoice_cli/ledger.py invoice_cli/parse.py
printf 'changed\n' >>"$repo/invoice_cli/export.py"
unreleased "Export one CSV for each supplier."
commit "feat(export): one csv per supplier"
lead='| N1 | A05:2025 Injection | invoice_cli/cli.py:12 main | a file name may reach a shell | whether the shell splits the name |'
run cut "$repo" --version 1.5.0 --date 2026-10-02 \
  --pentest "$(pass_report 1.5.0 "$lead" invoice_cli/export.py invoice_cli/cli.py)"
expect_exit 0 "$status" "lead cut: exits 0 (got: $(last_line "$out"))"
expect_match '^Coverage   2 of 5 files checked by a pentest · 3 not checked · ledger started$' "$(last_line "$out")" "lead cut: a file with a lead counts as checked by a pentest"
has_row invoice_cli/cli.py "lead in v1.5.0"
expect_exit 0 "$?" "lead cut: the file with the lead is marked lead in v1.5.0"
has_row invoice_cli/export.py v1.5.0
expect_exit 0 "$?" "lead cut: the range file is marked v1.5.0"
expect_match '^\*\*Units:\*\* 5 · \*\*Checked:\*\* 1 · \*\*Lead:\*\* 1 · \*\*Not checked:\*\* 3$' "$(cat "$repo/docs/security/coverage.md")" "lead cut: the header counts the lead"
released 1.5.0
printf 'changed again\n' >>"$repo/invoice_cli/export.py"
unreleased "Name the supplier in each row."
commit "feat(export): name the supplier"
run pick "$repo"
expect_exit 0 "$status" "pick after a lead: exits 0"
expected="Old files  4 of 4 not checked · docs/security/coverage.md
$(old_files 23 "lead in v1.5.0" invoice_cli/cli.py)
$(old_files 23 unchecked check.sh invoice_cli/ledger.py invoice_cli/parse.py)"
[ "$out" = "$expected" ]
expect_exit 0 "$?" "pick after a lead: the file with the lead comes first (got: $out)"
run cut "$repo" --version 1.6.0 --date 2026-10-09 --pentest "$(pass_report 1.6.0 "" invoice_cli/cli.py)"
expect_exit 0 "$status" "cut after a lead: exits 0 (got: $(last_line "$out"))"
has_row invoice_cli/cli.py v1.6.0
expect_exit 0 "$?" "cut after a lead: checked with no lead, it is marked v1.6.0"
has_row invoice_cli/export.py unchecked
expect_exit 0 "$?" "cut after a lead: a range file the pentest did not check is unchecked"

# 5. A ledger cut cannot read stops the release, and pick refuses it the same
# way. A Files checked path that git does not track is refused too. Each
# writes nothing. A missing ledger is no error: cases 1 and 4 started one.
released 1.6.0
printf 'changed\n' >>"$repo/invoice_cli/parse.py"
unreleased "Parse the due date."
commit "feat(parse): read the due date"
good=$repo
for shape in twice badmark badrow notable untracked; do
  repo="$work/refused-$shape"
  cp -R "$good" "$repo"
  ledger="$repo/docs/security/coverage.md"
  report=$(pass_report 1.7.0 "" invoice_cli/parse.py)
  case $shape in
    twice)     printf '| invoice_cli/cli.py | v1.6.0 |\n' >>"$ledger"
               want="Coverage ledger unreadable: line $(wc -l <"$ledger" | tr -d ' '): invoice_cli/cli.py is listed twice" ;;
    badmark)   sed -i.bak 's/^| invoice_cli\/cli\.py | v1\.6\.0 |$/| invoice_cli\/cli.py | v1.6 |/' "$ledger" && rm "$ledger.bak"
               want="Coverage ledger unreadable: line $(grep -n 'v1\.6 |$' "$ledger" | cut -d: -f1): the mark \"v1.6\" is not vX.Y.Z, lead in vX.Y.Z, reset in vX.Y.Z or unchecked" ;;
    badrow)    printf '| invoice_cli/extra.py | v1.6.0 | extra |\n' >>"$ledger"
               want="Coverage ledger unreadable: line $(wc -l <"$ledger" | tr -d ' '): | invoice_cli/extra.py | v1.6.0 | extra | is not a File and Mark row" ;;
    notable)   printf '# Coverage\n\nNo rows yet.\n' >"$ledger"
               want="Coverage ledger unreadable: no File and Mark table" ;;
    untracked) report=$(pass_report 1.7.0 "" invoice_cli/parse.py invoice_cli/nobody.py)
               want="Pentest report unreadable: Files checked names invoice_cli/nobody.py, which git does not track" ;;
  esac
  [ "$shape" = untracked ] || commit "docs: change the ledger"
  before=$(snapshot "$repo")
  run cut "$repo" --version 1.7.0 --date 2026-10-16 --pentest "$report"
  expect_exit 1 "$status" "refused ($shape): cut exits 1"
  grep -qxF -e "$want" <<<"$out"
  expect_exit 0 "$?" "refused ($shape): cut prints \"$want\" (got: $out)"
  expect_match '^Nothing written\.$' "$(last_line "$out")" "refused ($shape): cut says nothing was written"
  expect_match "^$before\$" "$(snapshot "$repo")" "refused ($shape): nothing written"
  [ "$shape" = untracked ] && continue
  run pick "$repo"
  expect_exit 1 "$status" "refused ($shape): pick exits 1"
  [ "$out" = "$want" ]
  expect_exit 0 "$?" "refused ($shape): pick prints the same line (got: $out)"
done
