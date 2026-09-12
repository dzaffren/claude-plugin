# scripts/block-attribution.sh -- the PreToolUse guard on commit messages.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

work=$(mktemp -d)
repo="$work/repo"
mkdir -p "$repo"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester
echo one >"$repo/a.txt"
git -C "$repo" add a.txt
git -C "$repo" commit -q -m "feat(repo): first commit" --no-verify

run_hook() {   # run_hook <shell command>; sets $hook_out $hook_err $hook_status
  local payload
  payload=$(ZUKO_CMD="$1" python3 -c 'import json,os; print(json.dumps({"tool_input":{"command":os.environ["ZUKO_CMD"]}}))')
  hook_out=$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$repo" bash "$scripts/block-attribution.sh" 2>"$work/err")
  hook_status=$?
  hook_err=$(cat "$work/err")
}

# The harness must never report a pass on a scope it did not scan.
bash "$scripts/tests/run.sh" no-such-test >/dev/null 2>&1
expect_exit 1 $? "run.sh errors on a test name that matches nothing"

run_hook 'git commit -m "feat(ship): standardise git naming

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"'
expect_exit 2 "$hook_status" "blocks a Co-Authored-By trailer naming Claude"
expect_match 'Co-Authored-By: Claude Opus 5' "$hook_err" "stderr quotes the offending line"
expect_match 'Remove' "$hook_err" "stderr says to remove it"
expect_match 'attribution.*settings\.json' "$hook_err" "stderr names the settings fix"

run_hook 'git commit -m "fix(hooks): tighten the matcher

co-authored-by: claude opus 5 <noreply@anthropic.com>"'
expect_exit 2 "$hook_status" "blocks a lowercase co-authored-by key"

run_hook 'git commit -m "docs(spec): record the convention

Claude-Session: https://claude.ai/code/session_01SXGpxYGgMK3E6G6kCNgi83"'
expect_exit 2 "$hook_status" "blocks a Claude-Session trailer"

run_hook 'git commit -m "chore: bump the version

See https://claude.ai/code/session_01SXGpxYGgMK3E6G6kCNgi83 for the log."'
expect_exit 2 "$hook_status" "blocks a bare claude.ai session link"

run_hook 'git commit -m "feat(build): add the runner

Generated with Claude Code"'
expect_exit 2 "$hook_status" "blocks a Generated with Claude Code line"

run_hook 'git commit -m "feat(ship): standardise git naming"'
expect_exit 0 "$hook_status" "allows a clean conventional commit"
expect_no_match '.' "$hook_out" "a passing hook prints nothing on stdout"
expect_no_match '.' "$hook_err" "a passing hook prints nothing on stderr"

run_hook 'git commit -m "feat(ship): pair on the gate

Co-Authored-By: Jane Doe <jane@example.com>"'
expect_exit 0 "$hook_status" "allows a Co-Authored-By trailer naming a human"

run_hook 'git commit'
expect_exit 0 "$hook_status" "allows a commit with no message on the command line"

printf 'feat(ship): from a file\n\nCo-Authored-By: Claude Opus 5 <noreply@anthropic.com>\n' >"$work/msg.txt"
run_hook "git commit -F $work/msg.txt"
expect_exit 2 "$hook_status" "blocks a trailer inside a -F message file"

printf 'feat(ship): from a clean file\n\nWhy it changed.\n' >"$work/clean.txt"
run_hook "git commit -F $work/clean.txt"
expect_exit 0 "$hook_status" "allows a clean -F message file"

run_hook 'git commit -am "feat(ship): staged and signed

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"'
expect_exit 2 "$hook_status" "blocks a trailer behind a clustered -am"

run_hook 'git commit -m"feat(ship): attached value

Claude-Session: https://claude.ai/code/session_01SX"'
expect_exit 2 "$hook_status" "blocks a trailer in an attached -m value"

run_hook 'git log --grep="Co-Authored-By: Claude" --oneline'
expect_exit 0 "$hook_status" "allows the trailer as a search argument to git log"

run_hook 'echo "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"'
expect_exit 0 "$hook_status" "allows the trailer in a command that is not a commit"

before=$(git -C "$repo" rev-list --count HEAD)
run_hook 'git commit -m "feat: x

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"'
after=$(git -C "$repo" rev-list --count HEAD)
expect_exit "$before" "$after" "the blocked hook creates no commit"

rm -rf "$work"
