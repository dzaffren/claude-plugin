# One walk through exe-lookup: on Windows, a git.exe or cygpath.exe at the
# root of the project folder never runs from a zuko hook or gate (D118,
# D119). The planted programs are copies of Git Bash's echo.exe, so a planted
# git prints its own arguments where git would print "git version".
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

if ! is_windows; then
  skip "e2e-exe-lookup: a git.exe and a cygpath.exe at the repo root never run" \
    "CreateProcess looks in the current folder on Windows only; test-program.sh checks argv() on every OS"
  return 0 2>/dev/null || exit 0
fi

work=$(mktemp -d -p "$work")
lib="$scripts/lib"
export HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME"

# acme-shop has an old breach on main: a Refined spec with an Open row. The
# branch changes nothing, so the Stop hook judges no doc (D35). A git that
# cannot see the work tree judges every doc instead, and fails the turn.
repo="$work/acme-shop"
g() { git -C "$repo" -c user.name=Zuko -c user.email=zuko@example.com -c commit.gpgsign=false "$@"; }
git init -q -b main "$repo"
mkdir -p "$repo/docs/specs"
cat >"$repo/docs/specs/checkout.md" <<'EOF'
# Checkout

**Version:** v1 · **Status:** Refined · **Type:** Feature · **Project type:** Web UI

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
| O1 | Can a gift card pay for shipping? | question | spec p1 | user | Open | — |
EOF
g add -A
g commit -q --no-verify -m "docs(spec): checkout"
g switch -q -c feat/basket
cp /usr/bin/echo.exe "$repo/git.exe"
cp /usr/bin/echo.exe "$repo/cygpath.exe"

# The hole is real here: a bare "git" from Python runs the planted copy.
# echo.exe treats a lone --version as its own, so give it two arguments.
raw=$(cd "$repo" && python3 -c 'import subprocess; print(subprocess.run(["git", "-C", "acme-shop", "--version"], capture_output=True, text=True).stdout.strip())')
expect_match '^-C acme-shop --version$' "$raw" "a bare git from Python in acme-shop runs the planted git.exe"

payload='{"session_id":"exe-lookup","transcript_path":"/dev/null","cwd":"/","permission_mode":"default","hook_event_name":"Stop","stop_hook_active":false}'
out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/check-open-items.sh" <<<"$payload" 2>&1)
expect_exit 0 $? "Stop hook in acme-shop: git from PATH sees the clean branch, so the old breach on main passes"

helper_version() {  # helper_version <module>: what <module>.git(acme-shop, "--version") prints, run in acme-shop
  (cd "$repo" && python3 -c 'import importlib.util, os, sys
sys.path.insert(0, sys.argv[1])
spec = importlib.util.spec_from_file_location("helper", os.path.join(sys.argv[1], sys.argv[2] + ".py"))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
try:
    done = helper.git(sys.argv[3], "--version")
    print((done if isinstance(done, str) else done.stdout).strip())
except FileNotFoundError as error:
    print("FileNotFoundError", error.filename)' "$lib" "$1" "$repo")
}

for module in changelog decisions stop_scope release-commit; do
  expect_match '^git version ' "$(helper_version "$module")" \
    "$module.git() in acme-shop starts the git.exe on PATH, not the planted one"
done

# No git on PATH: Python's folder and /usr/bin, which has echo.exe's DLL and no git.
nogit="$(dirname "$(type -P python3)"):/usr/bin"
said=$(PATH="$nogit" helper_version stop_scope)
expect_match '^FileNotFoundError git$' "$said" \
  "stop_scope.git() with no git on PATH fails as not found, and the planted git.exe does not run"

converted=$(cd "$repo" && python3 -c 'import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("git_command", os.path.join(sys.argv[1], "git-command.py"))
git_command = importlib.util.module_from_spec(spec)
spec.loader.exec_module(git_command)
print(git_command.native_path("/tmp/msg.txt"))' "$lib")
expect_match '^[A-Za-z]:/.*/msg\.txt$' "$converted" \
  "native_path in acme-shop converts /tmp/msg.txt with the cygpath.exe on PATH, not the planted one"
