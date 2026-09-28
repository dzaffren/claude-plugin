# scripts/secret-scan.sh -- the staged diff it scans is the one the commit
# takes: the directory the commit runs in, not the session's.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

repo="$work/secret-scan/repo"
wt="$work/secret-scan/wt"
mkdir -p "$repo"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Tester
echo one >"$repo/a.txt"
git -C "$repo" add a.txt
git -C "$repo" commit -q --no-verify -m "chore(repo): first commit"
git -C "$repo" worktree add -q -b feat/wt "$wt"

# A key-shaped value, assembled so this file never holds one whole.
key="AKIA""ABCDEFGHIJKLMNOP"
echo "aws=$key" >"$wt/creds.txt"
git -C "$wt" add creds.txt

scan() {   # scan <shell command> [<cwd>]; sets $scan_status
  local payload
  payload=$(ZUKO_CMD="$1" ZUKO_CWD="${2:-}" python3 -c 'import json,os
p={"tool_input":{"command":os.environ["ZUKO_CMD"]}}
if os.environ["ZUKO_CWD"]: p["cwd"]=os.environ["ZUKO_CWD"]
print(json.dumps(p))')
  printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$repo" bash "$scripts/secret-scan.sh" >/dev/null 2>&1
  scan_status=$?
}

scan 'git commit -m x' "$wt"
expect_exit 2 "$scan_status" "a secret staged where the session sits is blocked"

scan "cd $wt && git commit -m x"
expect_exit 2 "$scan_status" "a secret staged in the worktree a cd moves to is blocked"

scan "git -C $wt commit -m x"
expect_exit 2 "$scan_status" "a secret staged in the worktree -C points at is blocked"

scan 'git commit -m x'
expect_exit 0 "$scan_status" "a clean staged diff in the session's own repo passes"

scan "git -C $repo commit -m x" "$wt"
expect_exit 0 "$scan_status" "a commit pointed away from the secret's worktree passes"
