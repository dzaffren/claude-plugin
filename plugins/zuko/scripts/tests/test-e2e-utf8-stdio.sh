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
