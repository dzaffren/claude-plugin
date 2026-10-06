# scripts/check-design-drift.sh -- the UI drift gate: it reports each hit as
# <file>:<line>:<text>, and a file's name is only ever text in that report.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

proj="$work/design-drift"
mkdir -p "$proj/docs/design/share"
printf '.card { color: #ff0000; }\n' >"$proj/docs/design/share/card.css"
printf '.ok { color: var(--ink); }\n' >"$proj/docs/design/share/ok.css"

drift_out=$(cd "$proj" && CLAUDE_PROJECT_DIR="$proj" bash "$scripts/check-design-drift.sh" docs/design/share 2>&1)
expect_exit 1 "$?" "a raw hex colour fails the gate"
expect_match '^docs/design/share/card\.css:1:\.card \{ color: #ff0000; \}$' "$drift_out" "a hit is reported as file:line:text"
expect_no_match 'ok\.css' "$drift_out" "a file that uses tokens is not reported"

# Pentest P2: the name went into a sed program, so `|w <path>` in it made sed
# write a file. A name is data: reported whole, and nothing is written.
mkdir -p "$proj/docs/design/evil"
printf '.a { color: #ff0000; }\n' >"$proj/docs/design/evil/x|w pwned|.css"
before=$(cd "$proj" && find . | sort)
drift_out=$(cd "$proj" && CLAUDE_PROJECT_DIR="$proj" bash "$scripts/check-design-drift.sh" docs/design/evil 2>&1)
expect_exit 1 "$?" "a crafted file name still fails on its hex colour"
expect_exit 0 "$([ "$before" = "$(cd "$proj" && find . | sort)" ]; echo $?)" "a crafted file name writes no file"
expect_match '^docs/design/evil/x\|w pwned\|\.css:1:\.a \{ color: #ff0000; \}$' "$drift_out" "a crafted file name is reported whole"
