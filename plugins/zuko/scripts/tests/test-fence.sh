# scripts/verify-gates.sh and scripts/lib/fence.py -- a zuko doc in which a
# code block swallows the text after it fails the spec gate.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

work=$(mktemp -d -p "$work")
fence="$scripts/lib/fence.py"
repo_specs="$scripts/../../../docs/specs"

gate() {      # gate <project>; sets $gate_out $gate_status
  gate_out=$(CLAUDE_PROJECT_DIR="$1" bash "$scripts/verify-gates.sh" <<<'{}' 2>&1)
  gate_status=$?
}

line_of() {   # line_of <text>: the text as a whole-line regex
  printf '^%s$' "$(sed 's/[][\.*^$+?(){}|]/\\&/g' <<<"$1")"
}

# --- Scenario 1: a fence that opens inside an open block, end to end ---
# The real idea-board spec from a5cb93f: line 47 opens ```mermaid and never
# closes, and line 55 opens a second one inside it.
one="$work/one"
mkdir -p "$one/docs/specs"
cp "$scripts/tests/fixtures/fence/idea-board-a5cb93f.md" "$one/docs/specs/idea-board.md"
gate "$one"
expect_exit 2 "$gate_status" "inside a block: the gate fails"
expect_match '^Spec gate check failed:$' "$gate_out" "inside a block: inside the spec gate block"
expect_match "$(line_of "- $one/docs/specs/idea-board.md line 55 opens a \`\`\`mermaid block inside the block that line 47 opened. Close the block from line 47 first, or open it with a longer fence.")" \
  "$gate_out" "inside a block: names the doc, the open block and the fence inside it"
same_count=$(grep -c 'idea-board.md line ' <<<"$gate_out")
expect_match '^1$' "$same_count" "inside a block: one line for the doc, for its first problem"

# --- Scenario 2: a block still open at the end of the file ---
two="$work/two"
mkdir -p "$two/docs/specs"
{
  printf '# refunds\n\n**Version:** v1 · **Status:** Draft · **Type:** Feature\n\n## Open items\n\n_Never delete this section._\n'
  for _ in $(seq 8 39); do echo; done
  printf '```gherkin\nScenario: a refund\n  Then it is sent\n'
} >"$two/docs/specs/refunds.md"
gate "$two"
expect_exit 2 "$gate_status" "open at end: the gate fails"
expect_match "$(line_of "- $two/docs/specs/refunds.md: the \`\`\`gherkin block that line 40 opened never closes. Close it.")" \
  "$gate_out" "open at end: names the doc and the line that opened the block"

# --- Scenario 3: a block nested inside a longer fence passes ---
three="$work/three"
mkdir -p "$three/docs/specs"
cp "$repo_specs/decision-pr.md" "$three/docs/specs/decision-pr.md"
gate "$three"
expect_no_match 'opens a |never closes' "$gate_out" 'nested: a four-backtick block inside a five-backtick one passes'
all=$(python3 "$fence" check "$repo_specs"/*.md "$repo_specs"/*/shape.md 2>&1)
expect_exit 0 "$?" "nested: fence.py reads every spec and shape in the repo"
expect_match '^$' "$all" "nested: every spec and shape in the repo passes"

# --- Scenario 4: a doc this work did not change is not judged ---
four="$work/four"
mkdir -p "$four/docs/specs"
git init -q -b main "$four"
cp "$scripts/tests/fixtures/fence/idea-board-a5cb93f.md" "$four/docs/specs/idea-board.md"
printf '# replay\n\n**Version:** v1 · **Status:** Draft · **Type:** Feature\n\n## Open items\n\n_Never delete this section._\n' \
  >"$four/docs/specs/replay.md"
git -C "$four" add -A
git -C "$four" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit -q -m "docs: two specs"
git -C "$four" checkout -q -b feat/replay
echo "More text." >>"$four/docs/specs/replay.md"
gate "$four"
expect_no_match 'opens a |never closes' "$gate_out" "untouched: a broken spec on main is not judged"
expect_exit 0 "$gate_status" "untouched: the gate passes"

# --- fence.py alone ---
cases="$work/cases"
mkdir -p "$cases"
printf 'Text.\n\n~~~mermaid\nflowchart LR\n~~~gherkin\nScenario: x\n~~~\n~~~\n' >"$cases/tilde.md"
expect_match "$(line_of "$cases/tilde.md	line 5 opens a ~~~gherkin block inside the block that line 3 opened. Close the block from line 3 first, or open it with a longer fence.")" \
  "$(python3 "$fence" check "$cases/tilde.md")" "tilde: a tilde fence is read as a backtick one is"
printf 'Text.\n\n   ```text\nkept\n   ```\n' >"$cases/indented.md"
expect_match '^$' "$(python3 "$fence" check "$cases/indented.md")" "indented: a fence indented 3 spaces opens and closes"
printf 'Text.\n\n```\nplain block\n' >"$cases/plain.md"
expect_match "$(line_of "$cases/plain.md	the \`\`\` block that line 3 opened never closes. Close it.")" \
  "$(python3 "$fence" check "$cases/plain.md")" "no language: the fence is printed alone"
printf '```text\n~~~mermaid\n```\n' >"$cases/mixed.md"
expect_match '^$' "$(python3 "$fence" check "$cases/mixed.md")" "mixed: a tilde fence inside a backtick block is text"
out=$(python3 "$fence" check "$cases/missing.md" 2>&1)
expect_exit 2 "$?" "unreadable: fence.py exits 2"
expect_match '^fence\.py: cannot read .*missing\.md' "$out" "unreadable: says which doc"
out=$(python3 "$fence" 2>&1)
expect_exit 2 "$?" "usage: no command exits 2"

# --- the gate when fence.py cannot read a doc ---
bad="$work/bad"
mkdir -p "$bad/docs/specs"
printf '# odd\n\n**Version:** v1 · **Status:** Draft\n\n## Open items\n' >"$bad/docs/specs/odd.md"
printf '\xff\xfe\n' >>"$bad/docs/specs/odd.md"
gate "$bad"
expect_match '^- the fence check could not run: fence\.py: cannot read .*odd\.md' "$gate_out" "could not run: the gate says so"

# --- any Status (D76): a Shipped spec with a broken fence fails too ---
shipped="$work/shipped"
mkdir -p "$shipped/docs/specs"
printf '# ledger\n\n**Version:** v1 · **Status:** Shipped · **Type:** Feature\n\n```text\nopen\n\n## Open items\n' \
  >"$shipped/docs/specs/ledger.md"
gate "$shipped"
expect_exit 2 "$gate_status" "any Status: a Shipped spec with a broken fence fails the gate"
expect_match "$(line_of "- $shipped/docs/specs/ledger.md: the \`\`\`text block that line 5 opened never closes. Close it.")" \
  "$gate_out" "any Status: names the Shipped spec"

