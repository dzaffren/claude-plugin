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

scan() {   # scan <shell command> [<cwd>]; sets $scan_status $scan_err
  local payload
  payload=$(ZUKO_CMD="$1" ZUKO_CWD="${2:-}" python3 -c 'import json,os
p={"tool_input":{"command":os.environ["ZUKO_CMD"]}}
if os.environ["ZUKO_CWD"]: p["cwd"]=os.environ["ZUKO_CWD"]
print(json.dumps(p))')
  scan_err=$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$repo" bash "$scripts/secret-scan.sh" 2>&1 >/dev/null)
  scan_status=$?
}

scan 'git commit -m x' "$wt"
expect_exit 2 "$scan_status" "a secret staged where the session sits is blocked"
scan 'echo "$(git commit -m x)"' "$wt"
expect_exit 2 "$scan_status" "a commit in a quoted substitution has its staged diff scanned"

# A lone surrogate the payload parse cannot print used to end in `|| exit 0`
# before the staged diff was read (pentest P4).
surrogate_err=$(printf '{"tool_input":{"command":"git commit -m x \\ud800"},"cwd":"%s"}' "$wt" \
  | CLAUDE_PROJECT_DIR="$repo" bash "$scripts/secret-scan.sh" 2>&1 >/dev/null)
expect_exit 2 "$?" "a payload that will not decode blocks instead of skipping the scan"
expect_match '^Blocked: could not read the hook payload' "$surrogate_err" "the unreadable-payload block says why"

scan "cd $wt && git commit -m x"
expect_exit 2 "$scan_status" "a secret staged in the worktree a cd moves to is blocked"

scan "git -C $wt commit -m x"
expect_exit 2 "$scan_status" "a secret staged in the worktree -C points at is blocked"

scan 'git commit -m x'
expect_exit 0 "$scan_status" "a clean staged diff in the session's own repo passes"

scan "git -C $repo commit -m x" "$wt"
expect_exit 0 "$scan_status" "a commit pointed away from the secret's worktree passes"

# A mktemp -d repo is a Git Bash path on Windows, /tmp/tmp.X, which native
# Python could not place, so the scan read only the clean session repo and
# passed (guard-paths).
staged_repo=$(mktemp -d)
git -C "$staged_repo" init -q -b feat/refund-cap
printf 'aws_key = "%s"\n' "AKIA""IOSFODNN7EXAMPLE" >"$staged_repo/config.py"
git -C "$staged_repo" add config.py

scan "cd $staged_repo && git commit -m 'feat: cap refunds'" "$repo"
expect_exit 2 "$scan_status" "a secret staged in a mktemp -d repo a cd moves to is blocked"
expect_match 'aws_key = "AKIA' "$scan_err" "the cd block names the staged line"

scan "git -C $staged_repo commit -m x" "$repo"
expect_exit 2 "$scan_status" "a secret staged in a mktemp -d repo -C points at is blocked"

# branch-switch-commit: a commit whose directory the parser cannot know has the
# staged diff of each directory the command names scanned.
for form in "cd $staged_repo; git commit -m x" "cd $staged_repo && (git commit -m x)"; do
  scan "$form" "$repo"
  expect_exit 2 "$scan_status" "branch-switch-commit: a secret in a named dir is scanned, $(printf '%q' "$form")"
  expect_match 'aws_key = "AKIA' "$scan_err" "branch-switch-commit: the block names the staged line, $(printf '%q' "$form")"
done
scan "cd $staged_repo; cd $repo && git commit -m x" "$repo"
expect_exit 0 "$scan_status" "branch-switch-commit: a commit whose dir is known scans that dir only"
rm -rf "$staged_repo"

# Move the secret into the project repo. A commit that reaches it through a
# move the walk cannot follow must still have it scanned.
git -C "$wt" reset -q
echo "aws=$key" >"$repo/creds.txt"
git -C "$repo" add creds.txt

scan "cd -- $repo && git commit -m x" "$wt"
expect_exit 2 "$scan_status" "a secret reached by cd -- is scanned"

scan 'cd "$R" && git commit -m x' "$wt"
expect_exit 2 "$scan_status" "a secret reached by an unresolvable cd is scanned"

scan "pushd $wt && popd && git commit -m x" "$repo"
expect_exit 2 "$scan_status" "a secret left behind by pushd and popd is scanned"

# The scan reads what the commit takes: the work tree for -a, the text of each
# path it names, and a file whose diff git hides, as text (secret-scan-scope).
# Each block-case passed before, with exit 0.
git -C "$repo" reset -q
sc="$work/secret-scan/scope"
mkdir -p "$sc"
git -C "$sc" init -q -b feat/scope
git -C "$sc" config user.email t@example.com
git -C "$sc" config user.name Tester
echo one >"$sc/a.txt"
echo two >"$sc/b.txt"
echo three >"$sc/my notes.txt"
git -C "$sc" add .
git -C "$sc" commit -q --no-verify -m "chore(repo): first commit"

echo "aws=$key" >>"$sc/a.txt"
scan 'git commit -am x' "$sc"
expect_exit 2 "$scan_status" "-am reads a secret in a tracked file that is not staged"
expect_match 'aws=AKIA' "$scan_err" "the -am block names the line"
scan 'git commit -a -m x' "$sc"
expect_exit 2 "$scan_status" "-a reads a secret in a tracked file that is not staged"
scan 'git commit --all -m x' "$sc"
expect_exit 2 "$scan_status" "--all reads a secret in a tracked file that is not staged"
scan "cd $sc && git commit -qam x" "$repo"
expect_exit 2 "$scan_status" "-qam in the repo a cd moves to reads its work tree"
scan 'git commit a.txt -m x' "$sc"
expect_exit 2 "$scan_status" "a named path is read from the work tree"
scan 'git commit -m x -- a.txt' "$sc"
expect_exit 2 "$scan_status" "a path after -- is read from the work tree"
scan 'git commit -i a.txt -m x' "$sc"
expect_exit 2 "$scan_status" "a path with -i is read from the work tree"
scan 'git commit -m "fix it" a.txt' "$sc"
expect_exit 2 "$scan_status" "a path after a quoted message is read from the work tree"
scan 'git commit -m x -- "$F"' "$sc"
expect_exit 2 "$scan_status" "a path the shell expands is judged on the whole work tree"
scan 'git commit -m "x' "$sc"
expect_exit 2 "$scan_status" "a commit the parser cannot read is judged on the whole work tree"
# A redirect is the shell's, not a path: `/dev/null` as a path made git diff
# fail, and the scan read nothing.
scan 'git commit a.txt -m x 2>/dev/null' "$sc"
expect_exit 2 "$scan_status" "a named path before a 2> redirect is read from the work tree"
scan 'git commit a.txt -m x > log.txt' "$sc"
expect_exit 2 "$scan_status" "a named path before a > redirect is read from the work tree"
scan 'git commit -m x a.txt </dev/null' "$sc"
expect_exit 2 "$scan_status" "a named path before a < redirect is read from the work tree"
scan 'git commit -m x -- a.txt 2>/dev/null' "$sc"
expect_exit 2 "$scan_status" "a path after -- and before a redirect is read from the work tree"
scan 'git commit -m x -- a.txt ../outside' "$sc"
expect_exit 2 "$scan_status" "a paths diff that git refuses is judged on the whole work tree"

scan 'git commit -m x' "$sc"
expect_exit 0 "$scan_status" "a plain commit does not take a secret that is not staged"
scan 'git commit -m "add a.txt"' "$sc"
expect_exit 0 "$scan_status" "a path in the message is not a path the commit takes"
scan 'git commit -ma' "$sc"
expect_exit 0 "$scan_status" "-ma is a message, not -a"
echo fixed >>"$sc/b.txt"
scan 'git commit b.txt -m "fix the typo"' "$sc"
expect_exit 0 "$scan_status" "a named path does not take a secret in another file"
scan 'git commit b.txt -m "fix the typo" >/dev/null 2>&1' "$sc"
expect_exit 0 "$scan_status" "a redirect target is not a path the commit takes"
scan 'git commit -m x 2>/dev/null' "$sc"
expect_exit 0 "$scan_status" "a plain commit with a redirect does not take a secret that is not staged"
git -C "$sc" checkout -q -- a.txt
scan 'git commit -am "update notes"' "$sc"
expect_exit 0 "$scan_status" "-am with a clean work tree passes"

echo "aws=$key" >>"$sc/my notes.txt"
scan "git commit -m x -- 'my notes.txt'" "$sc"
expect_exit 2 "$scan_status" "a named path with a space is read whole"
git -C "$sc" checkout -q -- .

# An added line whose text starts with ++ prints as +++, as the file header
# does.
echo "++aws=$key" >>"$sc/a.txt"
scan 'git commit -am x' "$sc"
expect_exit 2 "$scan_status" "-am reads a secret on a line that starts with ++"
scan 'git commit a.txt -m x' "$sc"
expect_exit 2 "$scan_status" "a named path reads a secret on a line that starts with ++"
git -C "$sc" add a.txt
scan 'git commit -m x' "$sc"
expect_exit 2 "$scan_status" "a staged secret on a line that starts with ++ is read"
git -C "$sc" reset -q
git -C "$sc" checkout -q -- .

# git diff skips a file with the assume-unchanged bit, and git commit <path>
# still takes its work-tree text. git commit -a does not.
git -C "$sc" update-index --assume-unchanged a.txt
echo "aws=$key" >>"$sc/a.txt"
scan 'git commit a.txt -m x' "$sc"
expect_exit 2 "$scan_status" "a named path with the assume-unchanged bit is read from the work tree"
scan 'git commit -m x -- .' "$sc"
expect_exit 2 "$scan_status" "a pathspec that matches a file with the assume-unchanged bit reads it"
scan 'git commit b.txt -m x' "$sc"
expect_exit 0 "$scan_status" "a named path does not take another file with the assume-unchanged bit"
scan 'git commit -am x' "$sc"
expect_exit 0 "$scan_status" "-am does not take a file with the assume-unchanged bit"
git -C "$sc" update-index --no-assume-unchanged a.txt
git -C "$sc" checkout -q -- .

# Attributes and config that change what git diff prints.
printf '*.dat -diff\n' >"$sc/.gitattributes"
echo "aws=$key" >"$sc/c.dat"
git -C "$sc" add .gitattributes c.dat
scan 'git commit -m x' "$sc"
expect_exit 2 "$scan_status" "a staged file with a -diff attribute is read as text"
printf '*.dat binary\n' >"$sc/.gitattributes"
git -C "$sc" add .gitattributes
scan 'git commit -m x' "$sc"
expect_exit 2 "$scan_status" "a staged file with a binary attribute is read as text"
printf '*.dat diff=hide\n' >"$sc/.gitattributes"
git -C "$sc" add .gitattributes
git -C "$sc" config diff.hide.textconv true
scan 'git commit -m x' "$sc"
expect_exit 2 "$scan_status" "a textconv driver does not hide a staged secret"
git -C "$sc" config --unset diff.hide.textconv
git -C "$sc" config diff.external true
scan 'git commit -m x' "$sc"
expect_exit 2 "$scan_status" "an external diff does not hide a staged secret"
git -C "$sc" config --unset diff.external
git -C "$sc" config color.ui always
scan 'git commit -m x' "$sc"
expect_exit 2 "$scan_status" "color.ui always does not hide a staged secret"
git -C "$sc" config --unset color.ui
mkdir -p "$sc/sub"
git -C "$sc" config diff.relative true
scan "cd $sc/sub && git commit -m x" "$sc"
expect_exit 2 "$scan_status" "diff.relative does not hide a staged secret outside the dir"
git -C "$sc" config --unset diff.relative

git -C "$sc" reset -q
printf 'bin\000ary\n' >"$sc/e.bin"
git -C "$sc" add e.bin
scan 'git commit -m x' "$sc"
expect_exit 0 "$scan_status" "a staged file with NUL bytes and no secret passes"
echo "aws=$key" >"$sc/d.txt"
git -C "$sc" add d.txt
scan 'git commit -m x' "$sc"
expect_exit 2 "$scan_status" "a staged file with NUL bytes does not hide a staged secret"
git -C "$sc" reset -q

# Every script with pipefail, not only this one: piped text lets grep -q exit
# at a match before printf writes its next line, printf dies of SIGPIPE, and
# pipefail reads the match as a miss (pipefail-grep-race). Only strace can
# force that race, so this reads the scripts instead of running them.
piped_grep_q='(^|[^|])\|[[:space:]]*grep([[:space:]]+-[^[:space:]]+)*[[:space:]]+(-[a-zA-Z]*q[a-zA-Z]*|--quiet|--silent)([[:space:]]|$)'
for f in "$scripts"/*.sh; do
  grep -q pipefail "$f" || continue
  lines=$(grep -nE "$piped_grep_q" "$f" | cut -d: -f1 | paste -sd, -)
  if [ -z "$lines" ]; then
    record PASS "$(basename "$f") pipes no text into grep -q"
  else
    record FAIL "$(basename "$f") pipes no text into grep -q" "piped into grep -q at line $lines"
  fi
done
