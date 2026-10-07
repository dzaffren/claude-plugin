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

# The release commit (D30): cut leaves a marker naming the version, HEAD and
# the files it wrote, and only the commit that matches all of it may land on
# main. A repo of its own, on main, so the branch check fires.
rel="$work/release-repo"
mkdir -p "$rel"
git -C "$rel" init -q -b main
git -C "$rel" config user.email t@example.com
git -C "$rel" config user.name Tester
printf '# Changelog\n' >"$rel/CHANGELOG.md"
printf '# invoice-cli\n' >"$rel/OVERVIEW.md"
git -C "$rel" add -A
git -C "$rel" commit -q --no-verify -m "chore(repo): first commit"
printf '# Changelog\n\n## [2.3.0] - 2026-10-06\n' >"$rel/CHANGELOG.md"
printf '# invoice-cli\n\n**Release:** v2.3.0\n' >"$rel/OVERVIEW.md"
git -C "$rel" add CHANGELOG.md OVERVIEW.md
mark() {       # mark: the marker cut writes for v2.3.0 at the current HEAD
  printf 'version 2.3.0\nhead %s\nCHANGELOG.md\nOVERVIEW.md\n' "$(git -C "$rel" rev-parse HEAD)" >"$rel/.git/zuko-release"
}
run_rel() {    # run_rel <shell command>; sets $hook_status $hook_err
  local payload
  payload=$(ZUKO_CMD="$1" ZUKO_CWD="$rel" python3 -c 'import json,os
print(json.dumps({"tool_input":{"command":os.environ["ZUKO_CMD"]},"cwd":os.environ["ZUKO_CWD"]}))')
  hook_err=$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$rel" bash "$scripts/block-dangerous.sh" 2>&1 >/dev/null)
  hook_status=$?
}
release_commit='git commit -m "chore(release): v2.3.0" -m "CHANGELOG.md: cut 2.3.0. OVERVIEW.md: Release v2.3.0."'

# Scenario 2: no marker, so a release subject is still a commit on main.
run_rel "$release_commit"
expect_exit 2 "$hook_status" "release: a release subject with no marker is blocked"
expect_match 'A release commit needs the marker' "$hook_err" "release: the block names the missing marker"

# Scenario 1: the commit cut prepared passes; a reworded line is the same file.
mark
printf '# Changelog\n\n## [2.3.0] - 2026-10-06\n\n- Reworded.\n' >"$rel/CHANGELOG.md"
git -C "$rel" add CHANGELOG.md
run_rel "$release_commit"
expect_exit 0 "$hook_status" "release: the commit cut prepared passes on main"
run_rel 'git commit -m "chore(release): v2.3.0" -m "CHANGELOG.md: [Unreleased] under [2.3.0], {a,b} and * quoted."'
expect_exit 0 "$hook_status" "release: brackets, braces and stars inside quotes are text"

# Scenario 3: the marker covers only what cut wrote, in the form step 4 writes.
mkdir -p "$rel/src"
printf 'print(1)\n' >"$rel/src/app.py"
git -C "$rel" add src/app.py
run_rel "$release_commit"
expect_exit 2 "$hook_status" "release: an extra staged file is blocked"
expect_match 'staged src/app\.py, which cut did not write' "$hook_err" "release: the block names the extra file"
git -C "$rel" rm -q --cached src/app.py
git -C "$rel" restore -q --staged OVERVIEW.md
run_rel "$release_commit"
expect_exit 2 "$hook_status" "release: a file cut wrote and is not staged is blocked"
expect_match 'cut wrote OVERVIEW\.md, which is not staged' "$hook_err" "release: the block names the missing file"
git -C "$rel" add OVERVIEW.md
run_rel 'git commit -m "chore(release): v2.4.0"'
expect_exit 2 "$hook_status" "release: another version's subject is blocked"
expect_match 'subject is "chore\(release\): v2\.4\.0", not "chore\(release\): v2\.3\.0"' "$hook_err" "release: the block names both subjects"
run_rel 'git commit -m "fix: tidy changelog"'
expect_exit 2 "$hook_status" "release: a non-release subject is blocked"
expect_match 'Create a branch first\.$' "$hook_err" "release: a non-release subject gets the ordinary block"
for form in 'git commit -a -m "chore(release): v2.3.0"' \
  'git commit --amend -m "chore(release): v2.3.0"' \
  'git commit -m "chore(release): v2.3.0" OVERVIEW.md' \
  'git commit -F msg.txt' \
  'git commit --no-verify -m "chore(release): v2.3.0"' \
  'git commit -m "chore(release): v2.3.0" && git commit -m "chore(release): v2.3.0"' \
  'git add src/app.py && git commit -m "chore(release): v2.3.0"' \
  'git commit -m "chore(release): v2.3.0" -m $(echo body --all)' \
  'git commit -m "chore(release): v2.3.0" -m `echo body --all`' \
  'git commit -m "chore(release): v2.3.0" -m {body,--all}' \
  'git commit -m "chore(release): v2.3.0" -m *' \
  'git commit -m "chore(release): v2.3.0" -m body?' \
  'git commit -m "chore(release): v2.3.0" -m [a-z]*' \
  'GIT_INDEX_FILE=.git/alt git commit -m "chore(release): v2.3.0"' \
  'git -c core.hooksPath=/dev/null commit -m "chore(release): v2.3.0"' \
  'git commit -m "chore(release): v2.3.0" -m body # note' \
  "$(printf 'git commit -m "chore(release): v2.3.0"\ngit add src/app.py')"; do
  run_rel "$form"
  expect_exit 2 "$hook_status" "release: blocked: $form"
done
# The guard reads the index before the call runs, so anything else in the call
# could change what the commit takes: the release commit is the whole call.
run_rel 'git add CHANGELOG.md OVERVIEW.md && git commit -m "chore(release): v2.3.0"'
expect_match 'the release commit is the whole Bash call' "$hook_err" "release: a staging step in the same call is named as the reason"
run_rel 'cd "$REPO" && git commit -m "chore(release): v2.3.0"'
expect_exit 2 "$hook_status" "release: a commit whose directory the text cannot say gets no exception"

# Scenario 5: once the commit lands HEAD moves, and the marker matches nothing.
git -C "$rel" commit -q --no-verify -m "chore(release): v2.3.0"
printf 'typo\n' >>"$rel/OVERVIEW.md"
git -C "$rel" add OVERVIEW.md
run_rel "$release_commit"
expect_exit 2 "$hook_status" "release: the same commit after the release landed is blocked"
expect_match 'A release commit needs the marker' "$hook_err" "release: a marker for an old HEAD is no marker"
run_rel 'git commit -m "docs: fix a typo"'
expect_exit 2 "$hook_status" "release: an ordinary commit after an abandoned release is blocked"

# A lone surrogate is valid JSON, but Python cannot print it as UTF-8. The
# parse used to end in `|| exit 0`, so the push ran unchecked (pentest P3).
surrogate_err=$(printf '%s' '{"tool_input":{"command":"git push --force origin feature-x \ud800"}}' \
  | CLAUDE_PROJECT_DIR="$repo" bash "$scripts/block-dangerous.sh" 2>&1 >/dev/null)
expect_exit 2 "$?" "a payload that will not decode blocks instead of passing"
expect_match '^Blocked: could not read the hook payload' "$surrogate_err" "the unreadable-payload block says why"

git -C "$repo" checkout -q -b feat/thing
run_hook 'git commit -m x'
expect_exit 0 "$hook_status" "the same commit on a feature branch is allowed"

rm -rf "$work"
