# One walk through guard-paths: feed a hook payload for each scenario to the
# real hooks, with every repo and file made by mktemp -d. Sourced by run.sh,
# which provides $scripts and the expect_* helpers. On Windows each path is a
# Git Bash path, /tmp/tmp.X, so this proves the conversion. On Linux and macOS
# it proves that nothing changed.

work=$(mktemp -d)

# The Claude session runs in a repo on a feature branch.
session="$work/session"
git init -q -b feat/guard-paths "$session"
git -C "$session" -c user.email=t@example.com -c user.name=Tester commit -q --allow-empty --no-verify -m "chore(repo): first commit"

hook() {   # hook <script> <shell command> [<agent_type>]; sets $hook_status $hook_err
  local payload
  payload=$(ZUKO_CMD="$2" ZUKO_CWD="$session" ZUKO_AGENT="${3:-}" python3 -c 'import json,os
p={"tool_input":{"command":os.environ["ZUKO_CMD"]},"cwd":os.environ["ZUKO_CWD"]}
if os.environ["ZUKO_AGENT"]: p["agent_type"]=os.environ["ZUKO_AGENT"]
print(json.dumps(p))')
  # perl's alarm, not coreutils timeout: macOS ships perl but not timeout.
  printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$session" perl -e 'alarm shift; exec @ARGV' 10 \
    bash "$scripts/$1" >/dev/null 2>"$work/err"
  hook_status=$?
  hook_err=$(cat "$work/err")
}

# Scenario 1: the attribution guard reads a Git Bash message file.
msgs=$(mktemp -d)
printf 'fix(refunds): stop a refund above the order total\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n' >"$msgs/commit-msg.txt"
hook block-attribution.sh "git commit -F $msgs/commit-msg.txt"
expect_exit 2 "$hook_status" "scenario 1: a signed -F file at a mktemp -d path is blocked"
expect_match '^Blocked: the commit message carries Claude attribution\.' "$hook_err" "scenario 1: the block names the commit message"

# Scenario 2: the main-branch guard follows a Git Bash directory.
on_main=$(mktemp -d)
git init -q -b main "$on_main"
git -C "$on_main" -c user.email=t@example.com -c user.name=Tester commit -q --allow-empty --no-verify -m "chore(repo): first commit"
hook block-dangerous.sh "git -C $on_main commit -m 'fix: round refunds'"
expect_exit 2 "$hook_status" "scenario 2: a -C commit into a mktemp -d repo on main is blocked"
expect_match '^Blocked: committing directly on main\. Create a branch first\.' "$hook_err" "scenario 2: the block says to create a branch"

# Scenario 3: the secret scan follows a cd into a Git Bash directory.
staged=$(mktemp -d)
git init -q -b feat/refund-cap "$staged"
printf 'aws_key = "%s"\n' "AKIA""IOSFODNN7EXAMPLE" >"$staged/config.py"
git -C "$staged" add config.py
hook secret-scan.sh "cd $staged && git commit -m 'feat: cap refunds'"
expect_exit 2 "$hook_status" "scenario 3: a staged key in a cd target is blocked"
expect_match 'aws_key = "AKIA' "$hook_err" "scenario 3: the block names the staged line"

# Scenario 4: a message the guard cannot read is blocked, on every OS.
hook block-attribution.sh "gh pr create --title 'fix: refund cap' --body-file $msgs/missing-msg.txt"
expect_exit 2 "$hook_status" "scenario 4: a missing --body-file is blocked"
expect_match "could not read the PR body file $msgs/missing-msg\\.txt," "$hook_err" "scenario 4: the block names $msgs/missing-msg.txt"

hook block-attribution.sh 'git commit -F "$TMPDIR/msg"'
expect_exit 2 "$hook_status" "scenario 4: a -F \$TMPDIR/msg is blocked"
expect_match 'could not read the commit message file \$TMPDIR/msg,' "$hook_err" "scenario 4: the block names \$TMPDIR/msg"

hook block-attribution.sh "git commit -F - <<'EOF'
fix: round refunds
EOF"
expect_exit 2 "$hook_status" "scenario 4: a -F - heredoc is blocked"
expect_match 'comes from stdin \(-F -\)\. The guard cannot read stdin' "$hook_err" "scenario 4: the block names stdin (-F -)"

# The /ship form writes the body file in its own call first, so it passes.
printf 'Adds the refund cap.\n' >"$msgs/zuko-pr-body.md"
hook block-attribution.sh "gh pr create --title 'fix: refund cap' --body-file $msgs/zuko-pr-body.md"
expect_exit 0 "$hook_status" "scenario 4: a clean body file written before the command passes"

# Scenario 5: the pentester fence lets a command into its scratch copy, and
# still blocks a path out of it.
scratch=$(mktemp -d)
hook scope-pentester-bash.sh "cd $scratch && grep -rn subprocess plugins/zuko/scripts" zuko:pentester
expect_exit 0 "$hook_status" "scenario 5: a cd into a mktemp -d scratch copy is allowed"
hook scope-pentester-bash.sh "cd /tmp/../c/Users/adzaf && ls" zuko:pentester
expect_exit 2 "$hook_status" "scenario 5: a cd out of /tmp through .. is still blocked"

rm -rf "$work" "$msgs" "$on_main" "$staged" "$scratch"
