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
same() {       # same <expected> <actual> <description>
  if [ "$2" = "$1" ]; then record PASS "$3"; else record FAIL "$3" "expected [$1], got [$2]"; fi
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

# --- Scenario 3: the PR body is UTF-8 with LF ---
# A copy of the shipped spec docs/specs/lf-checkout.md, whose PR body holds ·.
pr_spec="$scripts/tests/fixtures/utf8-stdio/lf-checkout.md"
PYTHONIOENCODING=cp1252 python3 "$lib/pr_body.py" render "$pr_spec" >"$dir/pr.txt" 2>"$dir/pr.err"
expect_exit 0 $? "pr body: render exits 0 with cp1252 stdio"
has_bytes " c2 b7 " "$dir/pr.txt" "pr body: · is the bytes C2 B7"
same 13 "$(wc -l <"$dir/pr.txt" | tr -d ' ')" "pr body: the output has 13 lines"
no_cr "$dir/pr.txt" "pr body: the output has no CR byte"

# --- Scenario 4: the release guard reads a non-ASCII file name from git ---
# LC_ALL=C with UTF-8 mode and locale coercion off makes subprocess text ASCII
# on Linux and macOS. Windows decodes it as cp1252 whatever LC_ALL says.
ascii_env=(PYTHONIOENCODING=cp1252 LC_ALL=C PYTHONUTF8=0 PYTHONCOERCECLOCALE=0)
locale_enc=$(env "${ascii_env[@]}" python3 -c 'import locale; print(locale.getpreferredencoding(False))' | tr -d '\r')
case "$locale_enc" in
  *[Uu][Tt][Ff]*8*) echo "  note: subprocess text is $locale_enc here, so scenario 4 proves nothing on this OS" >&2 ;;
esac
rel="$dir/release"
plugin="plugins/café-menu/.claude-plugin/plugin.json"
mkdir -p "$rel/plugins/café-menu/.claude-plugin"
git -C "$rel" init -q -b main
git -C "$rel" config user.email t@example.com
git -C "$rel" config user.name Tester
git -C "$rel" config core.autocrlf false
printf '{"name": "café-menu", "version": "2.5.0"}\n' >"$rel/$plugin"
git -C "$rel" add -A
git -C "$rel" commit -q --no-verify -m "chore(repo): first commit"
printf '{"name": "café-menu", "version": "2.6.0"}\n' >"$rel/$plugin"
git -C "$rel" add -A
printf 'version 2.6.0\nhead %s\n%s\n' "$(git -C "$rel" rev-parse HEAD)" "$plugin" >"$rel/.git/zuko-release"
payload=$(ZUKO_CWD="$rel" python3 -c 'import json, os
print(json.dumps({"tool_input": {"command": "git commit -m \"chore(release): v2.6.0\""}, "cwd": os.environ["ZUKO_CWD"]}))')
release_err=$(printf '%s' "$payload" | env "${ascii_env[@]}" CLAUDE_PROJECT_DIR="$rel" \
  bash "$scripts/block-dangerous.sh" 2>&1 >/dev/null)
expect_exit 0 $? "release: the guard lets the commit cut prepared through"
expect_no_match 'which cut did not write' "$release_err" "release: no staged file reads as unprepared"
