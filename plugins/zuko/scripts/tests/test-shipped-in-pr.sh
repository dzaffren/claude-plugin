# /ship writes every file before the push, so the slice's own PR carries the
# Shipped status, and the close-out after the merge writes nothing. The rules
# are prompt text, so the first part checks the text. The second part walks a
# fixture slice from the refresh commit to the merge, and gives each git step
# to the hooks that hooks.json binds to it.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

zuko=$(dirname "$scripts")
ship="$zuko/skills/ship/SKILL.md"
visual="$zuko/references/visual-page.md"

# One line per section, whitespace squeezed, so a sentence wrapped across
# lines still matches. A "## " line inside a fence ends a section here, so a
# line under a fenced example is checked against the whole file instead.
section() { [ -f "$1" ] && awk -v h="## $2" '$0==h{f=1;next} /^## /{f=0} f' "$1" | tr '\n' ' ' | tr -s ' ' || echo "(missing: $1)"; }
squeezed() { [ -f "$1" ] && tr '\n' ' ' <"$1" | tr -s ' ' || echo "(missing: $1)"; }

refresh=$(section "$ship" "Refresh the overview")
gates=$(section "$ship" "The gates")
confirm=$(section "$ship" "Confirm it works")
close=$(section "$ship" "Close out")
hub=$(section "$visual" "Hub page")

# --- the refresh writes everything, on the branch (scenario 1) ---
expect_match 'Every file /ship writes, it writes here, on the branch, before the push\. The merge carries them to the base branch, and after the merge /ship writes nothing\.' \
  "$refresh" "ship refresh: every write is before the push"
expect_match "set this slice's row to \`Shipped\`" "$refresh" "ship refresh: the row is set to Shipped"
expect_no_match 'row to `Built`' "$refresh" "ship refresh: the row is no longer set to Built"
expect_match '- Spec Status → `Shipped`\.' "$refresh" "ship refresh: the spec is set to Shipped"
expect_match 'Republish the hub page from `OVERVIEW\.md` and `docs/ARCHITECTURE\.md`, per `\$\{CLAUDE_PLUGIN_ROOT\}/references/visual-page\.md`\. First publish → add the `hub page: \{url\}` it returns to the overview.s `## More` line\.' \
  "$refresh" "ship refresh: the hub is republished, and a first link goes on the More line"
expect_match 'Capture lessons to `docs/learnings/` silently\. A lesson found after the merge goes in the next branch.s refresh commit\.' \
  "$refresh" "ship refresh: lessons are captured here"
expect_match 'Commit these files, the spec, `README\.md`, `CHANGELOG\.md`, the lessons and any new `DECISIONS\.md` included, on the branch — `docs\(overview\): mark \{slice\} shipped`\.' \
  "$refresh" "ship refresh: one commit, mark shipped"
expect_match 'Spec Status → `Shipped`.*Republish the hub page.*render-readme-block\.sh --write.*Capture lessons.*mark \{slice\} shipped' \
  "$refresh" "ship refresh: every write comes before the commit"
expect_match '- Take the base branch into this one first, as "Tidy the branch" says\. The hub page below is published from this branch.s files, so a branch behind its base would publish a hub without the slices and the release merged since\.' \
  "$refresh" "ship refresh: the base branch comes in before the hub is published"
expect_match 'Take the base branch into this one first.*Republish the hub page' "$refresh" "ship refresh: the base is taken before the hub"
expect_no_match 'mark \{slice\} built' "$(squeezed "$ship")" "ship: the mark built commit is gone"

# --- the hub is built before the push (scenario 1, O1) ---
expect_match 'Built by `/ship` before the push, in the slice.s own PR, and republished by `/release`' \
  "$hub" "visual-page hub: /ship builds it before the push"
expect_no_match 'close-out' "$hub" "visual-page hub: not at close-out"

# --- the close-out writes nothing (scenario 2) ---
expect_match 'Write no file, and make no commit and no branch\.' "$close" "ship close: no file, no commit, no branch"
for gone in 'Flip this slice' 'render-readme-block' 'Republish the hub' 'Spec Status' 'Capture lessons'; do
  expect_no_match "$gone" "$close" "ship close: no longer does '$gone'"
done
expect_match '\*\*Graduation:\*\*' "$close" "ship close: graduation stays"
expect_match 'Print the next slice from the shape doc, and the command to start it\.' "$close" "ship close: the next slice stays"

# --- the gate gets the spec path (scenario 3, D61) ---
expect_match 'Run `\$\{CLAUDE_PLUGIN_ROOT\}/scripts/verify-ship-gates\.sh docs/specs/\{slice\}\.md`\.' \
  "$gates" "ship gates: the gate is given the spec path"
expect_match 'with no path the gate looks only for a `Built` spec\.' "$gates" "ship gates: says why the path is needed"
expect_match 'A second `/ship` run that changes nothing makes no commit\.' "$refresh" "ship refresh: a second run with no change makes no commit"
expect_match 'Before you route to `/spec` or `/build`, set the spec and its row back to `Built`, republish the idea board, run `render-readme-block\.sh --write` again, and commit\. The slice is not shipped until its PR merges, and `/spec` starts a new version of a `Shipped` spec\.' \
  "$gates" "ship gates: a failed gate puts the spec back to Built before /spec"

# --- a missing signal (scenario 4) ---
expect_match 'Send the user to `/debug`, and put any fix on a `fix/` branch\.' "$confirm" "ship confirm: a missing signal goes to /debug"
expect_match 'The spec stays `Shipped`' "$confirm" "ship confirm: the spec stays Shipped"

# --- the e2e walk: refresh commit to merge ---
work=$(mktemp -d)
repo="$work/repo"
mkdir -p "$repo/docs/specs"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester

write_overview() {   # write_overview <export-csv row status, or empty for no row>
  {
    cat <<'OVERVIEW'
# invoice-cli

**Status:** Active · **Updated:** 2026-10-13 by /ship export-csv

Turns a folder of supplier invoices into one ledger CSV.

## Run it

| Task    | Command            |
| ------- | ------------------ |
| install | `pip install -e .` |

## Slices

| Slice      | Status  | What it does                    | Page                  |
| ---------- | ------- | ------------------------------- | --------------------- |
| import-csv | Shipped | Read supplier invoices from CSV | https://claude.ai/... |
OVERVIEW
    [ -n "$1" ] && printf '| export-csv | %s | Export the ledger as one CSV | https://claude.ai/... |\n' "$1"
    printf '\n## More\n\nREADME.md%s\n' "${2:-}"
  } >"$repo/OVERVIEW.md"
}

render() {      # render <flag>; sets $render_status
  CLAUDE_PROJECT_DIR="$repo" bash "$scripts/render-readme-block.sh" "$1" >/dev/null 2>&1
  render_status=$?
}

gate() {        # gate [<spec>]; sets $gate_out and $gate_status
  gate_out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/verify-ship-gates.sh" "$@" 2>&1)
  gate_status=$?
}

hook() {        # hook <script> <shell command>; sets $hook_status, run in $repo
  ZUKO_CMD="$2" ZUKO_CWD="$repo" python3 -c 'import json,os
print(json.dumps({"tool_input":{"command":os.environ["ZUKO_CMD"]},"cwd":os.environ["ZUKO_CWD"]}))' \
    | CLAUDE_PROJECT_DIR="$repo" bash "$scripts/$1" >/dev/null 2>&1
  hook_status=$?
}

inside() {      # inside <README text>: the lines between the zuko markers
  awk '/^<!-- zuko:end -->$/ { inside = 0 } inside { print } /^<!-- zuko:start/ { inside = 1 }' <<<"$1"
}

# main: an onboarded repo, and another slice that main still has at Built.
write_overview ""
printf '# invoice-cli\n\n<!-- zuko:start — generated from OVERVIEW.md; edit that file, not this block -->\n<!-- zuko:end -->\n' >"$repo/README.md"
render --write
printf '# Decisions\n\nAppend-only. A changed decision is a new entry that supersedes the old one; only an\nold entry'"'"'s Status line ever changes.\n' >"$repo/DECISIONS.md"
python3 "$scripts/lib/changelog.py" init "$repo" >/dev/null
printf '# Import CSV\n\n**Version:** v1 · **Status:** Built\n' >"$repo/docs/specs/import-csv.md"
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "chore(repo): onboard invoice-cli"

# The slice branch, as /build left it: the fix, and the spec at Built.
git -C "$repo" checkout -q -b fix/export-csv
echo fixed >"$repo/export.py"
cat >"$repo/docs/specs/export-csv.md" <<'SPEC'
# Export CSV

**Version:** v1 · **Status:** Built · **Type:** Bug

| | |
| --- | --- |
| **Rollout** | No flag. Revert the merge commit. |
| **Proof it works** | The log line "export-csv: wrote 412 rows". |

**E2E:** test-export-csv.sh.

## Review

2026-10-13 · 2 raw findings, 0 survived. Clean.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
| O1 | Nothing is unresolved. | question | e2e | user | Resolved | Yes. |
SPEC
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "fix(export): keep the leading zeros in the CSV"

# 1. The refresh: the row, the spec, the CHANGELOG, the hub link, the README
# and a lesson, in one commit on the branch.
write_overview Shipped " · hub page: https://claude.ai/artifact/hub"
sed -i.bak 's/\*\*Status:\*\* Built/**Status:** Shipped/' "$repo/docs/specs/export-csv.md" && rm "$repo/docs/specs/export-csv.md.bak"
printf '\n### Fixed\n\n- The CSV export keeps the leading zeros of invoice numbers.\n' >>"$repo/CHANGELOG.md"
mkdir -p "$repo/docs/learnings"
printf '# Zeros are text\n\nRead an invoice number as text.\n' >"$repo/docs/learnings/zeros-are-text.md"
render --write
expect_exit 0 "$render_status" "e2e: the refresh renders the README block"

hook block-dangerous.sh 'git add -A'
expect_exit 0 "$hook_status" "e2e: the refresh's staging call passes block-dangerous.sh"
git -C "$repo" add -A
status_commit='git commit -m "docs(overview): mark export-csv shipped" -m "The row, the spec, the README and the hub link, in the PR."'
for script in block-dangerous.sh secret-scan.sh block-attribution.sh; do
  hook "$script" "$status_commit"
  expect_exit 0 "$hook_status" "e2e: the status commit on fix/export-csv passes $script"
done
git -C "$repo" commit -q --no-verify -m "docs(overview): mark export-csv shipped" -m "The row, the spec, the README and the hub link, in the PR."

expect_match '^docs\(overview\): mark export-csv shipped$' "$(git -C "$repo" log -1 --format=%s)" "e2e: the status commit's subject"
changed=$(git -C "$repo" show --name-only --format= HEAD)
for file in OVERVIEW.md docs/specs/export-csv.md README.md CHANGELOG.md docs/learnings/zeros-are-text.md; do
  expect_match "^${file//./\\.}\$" "$changed" "e2e: the status commit carries $file"
done
expect_match '\*\*Status:\*\* Shipped' "$(git -C "$repo" show HEAD:docs/specs/export-csv.md)" "e2e: the commit sets the spec to Shipped"
expect_match '^- Export the ledger as one CSV$' "$(inside "$(git -C "$repo" show HEAD:README.md)")" "e2e: the commit lists the slice under Features"

# 2. The gate, given the spec path, passes. With no path it gates the wrong one.
gate docs/specs/export-csv.md
expect_exit 0 "$gate_status" "e2e: the gate passes the Shipped spec on the branch"
expect_match '^Spec: docs/specs/export-csv\.md$' "$gate_out" "e2e: the gate checked export-csv"
expect_match '^Overview: row for "export-csv" found$' "$gate_out" "e2e: the gate found the Shipped row"
gate
expect_no_match '^Spec: .*export-csv\.md$' "$gate_out" "e2e: with no path the gate misses the Shipped spec"
expect_match '^Spec: .*import-csv\.md$' "$gate_out" "e2e: with no path the gate checks the other Built slice"

hook block-dangerous.sh 'git push -u origin fix/export-csv'
expect_exit 0 "$hook_status" "e2e: the push of fix/export-csv passes block-dangerous.sh"

# 3. A second /ship run after red CI: the render changes nothing, nothing is
# left to commit, and the gate still finds the spec.
cp "$repo/README.md" "$work/README.first"
render --write
cmp -s "$work/README.first" "$repo/README.md"
expect_exit 0 "$?" "e2e: a second render changes nothing"
expect_match '^$' "$(git -C "$repo" status --porcelain)" "e2e: a second run leaves nothing to commit"
gate docs/specs/export-csv.md
expect_exit 0 "$gate_status" "e2e: the second gate run passes"

# 4. The merge. GitHub makes it, so no hook sees it here.
git -C "$repo" checkout -q main
git -C "$repo" merge -q --no-ff -m "Merge pull request #1 from fix/export-csv" fix/export-csv
expect_match '^docs\(overview\): mark export-csv shipped$' "$(git -C "$repo" log --format=%s main^1..main^2)" "e2e: the status commit is inside the PR"
expect_match '\*\*Status:\*\* Shipped' "$(cat "$repo/docs/specs/export-csv.md")" "e2e: main has the spec at Shipped"
expect_match '^\| export-csv \| Shipped \|' "$(cat "$repo/OVERVIEW.md")" "e2e: main has the row at Shipped"
expect_match '^- Export the ledger as one CSV$' "$(inside "$(cat "$repo/README.md")")" "e2e: main's README lists the slice"
render --check
expect_exit 0 "$render_status" "e2e: main's README block is current"

# 5. The close-out cannot commit on main, and has nothing to commit.
hook block-dangerous.sh "$status_commit"
expect_exit 2 "$hook_status" "e2e: a close-out commit on main is blocked"
expect_match '^$' "$(git -C "$repo" status --porcelain)" "e2e: main has nothing left to commit"

rm -rf "$work"
