# drop-board: zuko publishes no claude.ai page. The stage rules are prompt
# text, so scenarios 1 to 3 check the text. Scenario 4 runs the real spec
# gate from a copy of scripts/ with board.py gone.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

work=$(mktemp -d -p "$work")
zuko=$(dirname "$scripts")
root=$(dirname "$(dirname "$zuko")")

squeezed() { [ -f "$1" ] && tr '\n' ' ' <"$1" | tr -s ' ' || echo "(missing: $1)"; }

# --- Scenario 1: no skill, reference or agent names the board ---
prompts=$(grep -rniE 'board\.py|board\.html|visual-page|idea board|hub page|published page|\.pages/|Board not published|\*\*Board:\*\*|\*\*Page:\*\*|`Board:`|--by "' \
  "$zuko/skills" "$zuko/references" "$zuko/agents" 2>&1)
expect_match '^$' "$prompts" "prompts: no stage names the board, the hub or the pages folder"
expect_exit 1 "$([ -e "$zuko/references/visual-page.md" ]; echo $?)" "prompts: visual-page.md is gone"
expect_exit 1 "$([ -e "$scripts/lib/board.py" ]; echo $?)" "scripts: board.py is gone"
expect_exit 1 "$([ -e "$scripts/lib/board.html" ]; echo $?)" "scripts: board.html is gone"

# --- Scenario 2: /shape ends with no board and no hub ---
shape=$(squeezed "$zuko/skills/shape/SKILL.md")
expect_no_match '[Pp]ublish' "$shape" "shape: no publish step"
expect_match 'print the problem in two sentences, the slice list with the diagram, and any open items' \
  "$shape" "shape: the terminal shows the problem, the slices and the open items"
onboard=$(squeezed "$zuko/references/onboard.md")
expect_no_match '\| Page \|' "$onboard" "onboard: the Slices template has no Page column"
expect_no_match 'hub page' "$onboard" "onboard: no hub page link"
expect_no_match 'specs/\.pages' "$onboard" "onboard: no step that ignores the pages folder"

# --- Scenario 3: /ship opens a PR with no page links ---
ship=$(squeezed "$zuko/skills/ship/SKILL.md")
expect_match 'One last line: `Spec: docs/specs/\{slice\}\.md`\.' "$ship" "ship: the PR body ends with the spec line"
expect_no_match ' · Page: | · Board: ' "$ship" "ship: no Page or Board part in the PR body"
expect_no_match '\*\*Page:\*\*' "$(squeezed "$zuko/skills/spec/references/spec-template.md")" "template: no Page line"
header=$(grep -m1 -E '^\| Slice +\|' "$root/OVERVIEW.md" | tr -s ' ')
expect_match '^\| Slice \| Status \| What it does \|$' "$header" "overview: the Slices table has no Page column"
expect_no_match 'hub page:' "$(squeezed "$root/OVERVIEW.md")" "overview: no hub page link"
for slice in idea-board gate-card pr-gate library replay slice-name-path; do
  expect_match "^\| $slice +\| Removed +\|" "$(grep -E "^\| $slice +\|" "$root/OVERVIEW.md")" "overview: $slice is Removed"
done

# --- Scenario 4: the unclosed-fence check works without board.py (e2e) ---
copy="$work/scripts"
mkdir -p "$copy"
cp -R "$scripts/lib" "$copy/lib"
cp "$scripts"/*.sh "$copy/"
rm -f "$copy/lib/board.py" "$copy/lib/board.html"
repo="$work/repo"
mkdir -p "$repo/docs/specs"
{
  printf '# plain-words\n\n**Version:** v1 · **Status:** Draft · **Type:** Enhancement\n\n'
  printf '## Interface\n\n```text\nzuko: 2 hard words in docs/specs/plain-words.md\n\n'
  printf '## Open items\n\n_Never delete this section._\n'
} >"$repo/docs/specs/plain-words.md"
gate_out=$(CLAUDE_PROJECT_DIR="$repo" bash "$copy/verify-gates.sh" <<<'{}' 2>&1)
expect_exit 2 "$?" "fence: the gate fails with board.py gone"
expect_match 'plain-words\.md: the ```text block that line 7 opened never closes\. Close it\.' \
  "$gate_out" "fence: names the spec and the line where the block opens"
expect_no_match 'board|Traceback|ModuleNotFoundError' "$gate_out" "fence: fence.py does not reach for board.py"
