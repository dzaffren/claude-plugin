# scripts/block-dangerous.sh -- the four scenarios hook-command-match could
# only run by hand, and the branch case that proves the commit rule both ways.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

work=$(mktemp -d)
repo="$work/repo"
mkdir -p "$repo"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester
echo one >"$repo/a.txt"
git -C "$repo" add a.txt
git -C "$repo" commit -q --no-verify -m "chore(repo): first commit"

run_hook() {   # run_hook <shell command>; sets $hook_status
  local payload
  payload=$(ZUKO_CMD="$1" python3 -c 'import json,os; print(json.dumps({"tool_input":{"command":os.environ["ZUKO_CMD"]}}))')
  printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$repo" bash "$scripts/block-dangerous.sh" >/dev/null 2>&1
  hook_status=$?
}

# The guard's verdict depends on the branch, so HEAD sits on main for the
# commit cases and on a feature branch for the last one.
run_hook 'cat > d.md <<EOF
git commit
EOF'
expect_exit 0 "$hook_status" "a commit named in a heredoc body is prose, not a command"

run_hook 'git commit -m x'
expect_exit 2 "$hook_status" "a real commit on main is blocked"

run_hook "echo 'git push --force'"
expect_exit 0 "$hook_status" "a force push inside a quoted string is text, not a command"

run_hook "git commit -m 'oops"
expect_exit 2 "$hook_status" "a command that will not parse fails closed"

git -C "$repo" checkout -q -b feat/thing
run_hook 'git commit -m x'
expect_exit 0 "$hook_status" "the same commit on a feature branch is allowed"

rm -rf "$work"
