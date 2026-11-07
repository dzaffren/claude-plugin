# e2e: zuko's Python reads and writes UTF-8 with LF, whatever the platform
# default is (spec utf8-stdio). PYTHONIOENCODING=cp1252 starts stdio as cp1252
# on every OS, as Windows does. Only Windows writes CRLF, so the no-CR checks
# prove the fix there only (spec O5).
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

lib="$scripts/lib"
dir=$(mktemp -d -p "$work")

# bytes <file>: the file as " e2 86 92 ..." with one space around each byte,
# so a match never starts halfway through a byte.
bytes() { printf ' %s ' "$(od -An -tx1 -v "$1" | tr -s ' \n' ' ')"; }
# crs <file>: the number of CR bytes. Git Bash's grep hides a CR at a line end.
crs() { tr -cd '\r' <"$1" | wc -c | tr -d ' '; }
has_bytes() {  # has_bytes <" e2 86 92 "> <file> <description>
  case "$(bytes "$2")" in
    *"$1"*) record PASS "$3" ;;
    *) record FAIL "$3" "no$1in $2" ;;
  esac
}
no_cr() {      # no_cr <file> <description>
  local n; n=$(crs "$1")
  if [ "$n" = 0 ]; then record PASS "$2"; else record FAIL "$2" "$n CR bytes in $1"; fi
}

# --- Scenario 1: the board renders on Windows ---
board_repo="$dir/board"
cp -R "$scripts/tests/fixtures/board" "$board_repo"
shape="$board_repo/docs/specs/stages/shape.md"
sed -i 's/A\[not-started\] --> B\[pause-one\]/A[not-started] -- "→ next" --> B[pause-one]/' "$shape"
expect_match '→ next' "$(cat "$shape")" "board: the fixture's slice map holds →"
PYTHONIOENCODING=cp1252 python3 "$lib/board.py" render "$shape" --by "/spec utf8-stdio pause 1" \
  >"$dir/board.html" 2>"$dir/board.err"
expect_exit 0 $? "board: render exits 0 with cp1252 stdio"
has_bytes " e2 86 92 " "$dir/board.html" "board: → is the bytes E2 86 92"
no_cr "$dir/board.html" "board: the HTML has no CR byte"

# --- Scenario 2: the session start shows the decisions correctly ---
dec_repo="$dir/decisions"
mkdir -p "$dec_repo"
cat >"$dec_repo/DECISIONS.md" <<'MD'
# Decisions

Append-only. A changed decision is a new entry that supersedes the old one; only an
old entry's Status line ever changes.

## D3 · 2026-09-25 · No feat, fix or breaking commit means no proposed release

Why: a version number promises a change.
Rejected: proposing a patch anyway (a release with nothing in it).
Source: specs/release.md
Status: active

## D4 · 2026-09-27 · Security severity is a 3 × 3 exploitability × impact grid

Why: one scale for every finding — the reviewer and the pentester share it.
Rejected: CVSS (too many inputs for a code review).
Source: specs/owasp-lens.md
Status: active
MD
PYTHONIOENCODING=cp1252 CLAUDE_PROJECT_DIR="$dec_repo" bash "$scripts/load-decisions.sh" \
  </dev/null >"$dir/session.txt" 2>&1
expect_exit 0 $? "session: load-decisions.sh exits 0"
grep '^  D4 ' "$dir/session.txt" >"$dir/d4.txt"
has_bytes " 33 20 c3 97 20 33 " "$dir/d4.txt" "session: × in the D4 line is the bytes C3 97"
no_cr "$dir/session.txt" "session: no line ends with a CR byte"
