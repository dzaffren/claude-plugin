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

run_hook() {   # run_hook <shell command> [<cwd>]; sets $hook_status
  local payload
  payload=$(ZUKO_CMD="$1" ZUKO_CWD="${2:-}" python3 -c 'import json,os
p={"tool_input":{"command":os.environ["ZUKO_CMD"]}}
if os.environ["ZUKO_CWD"]: p["cwd"]=os.environ["ZUKO_CWD"]
print(json.dumps(p))')
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

run_hook "git push \\
  --force origin main"
expect_exit 2 "$hook_status" "a force push wrapped over two lines is still a force push"

run_hook "git pu\\
sh --force origin main"
expect_exit 2 "$hook_status" "a continuation splitting the subcommand is still a force push"

# The commit lands in the directory it runs in, not the session's. A worktree
# on a feature branch sits beside a session on main, and the reverse.
wt="$work/wt"
git -C "$repo" worktree add -q -b feat/wt "$wt"

run_hook "cd $wt && git commit -m x"
expect_exit 0 "$hook_status" "a commit after cd into a feature worktree is allowed"

run_hook "git -C $wt commit -m x"
expect_exit 0 "$hook_status" "a commit with -C pointing at a feature worktree is allowed"

run_hook "git -C ../wt commit -m x"
expect_exit 0 "$hook_status" "a relative -C resolves from the session directory"

run_hook 'git commit -m x' "$wt"
expect_exit 0 "$hook_status" "the hook's cwd, not the project dir, decides the branch"

run_hook "cd $repo && git commit -m x" "$wt"
expect_exit 2 "$hook_status" "a commit after cd from a feature worktree onto main is blocked"

run_hook "git -C $repo commit -m x" "$wt"
expect_exit 2 "$hook_status" "a commit with -C pointing at main is blocked"

run_hook "(cd $wt && git commit -m x); git commit -m x"
expect_exit 2 "$hook_status" "a cd inside a subshell does not carry past it"

run_hook 'cd "$TARGET" && git commit -m x'
expect_exit 2 "$hook_status" "a cd the hook cannot resolve falls back to the session branch"

run_hook "cd $work/missing; git commit -m x"
expect_exit 2 "$hook_status" "a cd into a missing directory leaves the commit on the session branch"

run_hook "GIT_DIR=$wt/.git git commit -m x"
expect_exit 2 "$hook_status" "a GIT_DIR override falls back to the session branch"

# A cd the shell does not keep for the commit: the commit still lands on main.
run_hook "pushd $wt && popd && git commit -m x"
expect_exit 2 "$hook_status" "a popd back to main is not read as staying in the worktree"

run_hook "cd $wt | true; git commit -m x"
expect_exit 2 "$hook_status" "a cd inside a pipeline does not move the next command"

run_hook "cd $wt & git commit -m x"
expect_exit 2 "$hook_status" "a backgrounded cd does not move the next command"

run_hook "false && cd $wt; git commit -m x"
expect_exit 2 "$hook_status" "a cd that did not run does not move the next command"

run_hook "echo \`cd $wt\`; git commit -m x"
expect_exit 2 "$hook_status" "a cd inside backticks does not move the next command"

run_hook "cd $wt && git add . && git commit -m x"
expect_exit 0 "$hook_status" "a plain && chain into a feature worktree is still allowed"

# From the worktree, with the project dir on main: a move the walk cannot
# follow must not be judged in the worktree.
run_hook "{ cd $repo && git commit -m x; }" "$wt"
expect_exit 2 "$hook_status" "a cd inside braces onto main is blocked"

run_hook "if true; then cd $repo; fi; git commit -m x" "$wt"
expect_exit 2 "$hook_status" "a cd inside an if onto main is blocked"

run_hook 'cd "$R" && git commit -m x' "$wt"
expect_exit 2 "$hook_status" "an unresolvable cd is also judged on the project dir"

run_hook "cd -- $repo && git commit -m x" "$wt"
expect_exit 2 "$hook_status" "cd -- onto main is blocked"

run_hook "GIT_DIR=$repo/.git git commit -m x" "$wt"
expect_exit 2 "$hook_status" "a GIT_DIR pointing at main is blocked from a worktree"

run_hook "git --git-dir=$repo/.git commit -m x" "$wt"
expect_exit 2 "$hook_status" "a --git-dir pointing at main is blocked from a worktree"

git -C "$repo" checkout -q -b feat/thing
run_hook 'git commit -m x'
expect_exit 0 "$hook_status" "the same commit on a feature branch is allowed"

rm -rf "$work"
