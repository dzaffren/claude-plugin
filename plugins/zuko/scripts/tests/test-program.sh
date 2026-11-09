# scripts/lib/program.py -- find() walks the PATH folders in order, as Git
# Bash does, and never the current folder; argv() changes a command only on
# Windows (D107). The Windows branch runs here with os.name set to "nt", so
# its choice of file is checked on every OS.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

work=$(mktemp -d -p "$work")
lib="$scripts/lib"
# The real interpreter: argv_on runs it with a PATH of fixture folders only.
py=$(python3 -c 'import sys; print(sys.executable)')
# A found path prints as its folder/file, so the checks read the same on
# Windows, where Python gets each fixture path in C:\ form.
short='def short(p):
    return "/".join(os.path.normpath(p).split(os.sep)[-2:]) if p and os.path.isabs(p) else str(p)'

same() {  # same <expected> <actual> <description>
  if [ "$2" = "$1" ]; then record PASS "$3"
  else record FAIL "$3" "expected [$1], got [$2]"; fi
}

found() {  # found <name> <exts, ;-separated> [<folder>...]: what find() gives, or None
  "$py" -c "$PY_LF"'import os, sys; sys.path.insert(0, sys.argv[1]); import program
'"$short"'
exts = [e for e in sys.argv[3].split(";") if e]
print(short(program.find(sys.argv[2], os.pathsep.join(sys.argv[4:]), exts)))' "$lib" "$@"
}

argv_on() {  # argv_on <os.name> <PATH> <arg>...: argv() of the args, one per line
  local name=$1 path=$2
  shift 2
  PATH="$path" PATHEXT=".EXE" "$py" -c "$PY_LF"'import os, sys; sys.path.insert(0, sys.argv[1]); import program
'"$short"'
os.name = sys.argv[2]
try:
    print("\n".join(short(arg) for arg in program.argv(sys.argv[3:])))
except FileNotFoundError as error:
    print("FileNotFoundError", error.filename)' "$lib" "$name" "$@"
}

mkdir -p "$work/one" "$work/two" "$work/empty" "$work/here" "$work/sh" "$work/git"
printf '#!/bin/sh\necho stub\n' >"$work/one/gh"
printf 'MZ' >"$work/two/gh.EXE"
printf '#!/bin/sh\necho here\n' >"$work/here/gh"
mkdir "$work/empty/gh"
printf 'MZ' >"$work/sh/bash.EXE"
printf 'MZ' >"$work/git/git.EXE"

# --- find() ---
same "one/gh" "$(found gh .EXE "$work/one" "$work/two")" \
  "find: a stub gh in the first folder beats a gh.EXE in a later one"
same "two/gh.EXE" "$(found gh .EXE "$work/two" "$work/one")" "find: the folders are tried in PATH order"
same "one/gh" "$(found gh "" "$work/one")" "find: a name with no extension is found as it is"
same "two/gh.EXE" "$(found gh ".COM;.EXE" "$work/two")" \
  "find: a name with no bare file is found with a PATHEXT extension"
same "two/gh.EXE" "$(found gh .EXE "$work/empty" "$work/two")" "find: a folder named gh is not a program"
same "None" "$(cd "$work/here" && found gh .EXE "" . "$work/empty")" \
  "find: a gh in the current folder is not found, through an empty or relative PATH entry or none"
same "None" "$(found gh .EXE)" "find: an empty PATH finds nothing"

# --- argv() ---
same "$(printf 'gh\napi\nx y')" "$(argv_on posix "$work/one:$work/sh" gh api "x y")" \
  "argv: off Windows, the command is given back unchanged"
same "$(printf 'sh/bash.EXE\none/gh\napi')" "$(argv_on nt "$work/one:$work/sh" gh api)" \
  "argv on Windows: a #! script found on PATH runs through the bash found on PATH"
same "$(printf 'git/git.EXE\nstatus')" "$(argv_on nt "$work/git:$work/sh" git status)" \
  "argv on Windows: a program found with PATHEXT runs as itself"
same "FileNotFoundError gh" "$(argv_on nt "$work/empty:$work/sh" gh api)" \
  "argv on Windows: a name not on PATH raises FileNotFoundError, and is never given back bare"
same "FileNotFoundError bash" "$(argv_on nt "$work/one" gh api)" \
  "argv on Windows: a #! script with no bash on PATH raises FileNotFoundError for bash"
if [ "$(id -u)" != 0 ]; then
  mkdir -p "$work/locked"
  printf '#!/bin/sh\necho locked\n' >"$work/locked/gh"
  deny r "$work/locked/gh"
  same "$(printf 'locked/gh\napi')" "$(argv_on nt "$work/locked:$work/sh" gh api 2>&1)" \
    "argv on Windows: a found file that cannot be read is given back as its found path, not an error"
  allow "$work/locked/gh"
fi

# Git Bash expands {a}, * and [..] in the arguments that a native program
# hands it, so repos/{owner}/{repo} reached the stub as repos/owner/repo.
msys_after() {  # msys_after <MSYS value> <arg>...: MSYS after argv() on Windows
  local value=$1
  shift
  MSYS="$value" PATH="$work/one:$work/sh:$work/git" PATHEXT=".EXE" "$py" -c "$PY_LF"'import os, sys; sys.path.insert(0, sys.argv[1]); import program
os.name = "nt"
program.argv(sys.argv[2:])
print(os.environ.get("MSYS", ""))' "$lib" "$@"
}
same "noglob" "$(msys_after "" gh api 'repos/{owner}/{repo}')" \
  "argv on Windows: a #! script runs with MSYS=noglob, so bash keeps {owner} as typed"
same "winsymlinks:nativestrict noglob" "$(msys_after "winsymlinks:nativestrict" gh api)" \
  "argv on Windows: noglob is added to the MSYS options already set"
same "noglob" "$(msys_after "noglob" gh api)" "argv on Windows: noglob is not added twice"
same "" "$(msys_after "" git status)" "argv on Windows: a program that is not a script leaves MSYS alone"

# --- each program that zuko's Python starts (D119) ---
# On Windows each git() helper and native_path() must hand subprocess.run the
# absolute path that argv() found. A bare name lets CreateProcess run a
# git.exe or cygpath.exe from the project folder that the hook runs in.
mkdir -p "$work/cyg"
printf 'MZ' >"$work/cyg/cygpath.EXE"
started=$(PATH="$work/git:$work/cyg" PATHEXT=".EXE" "$py" -c "$PY_LF"'import importlib.util, os, subprocess, sys
'"$short"'
lib = sys.argv[1]
def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), os.path.join(lib, name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module
sys.path.insert(0, lib)
seen = []
def run(args, **options):
    seen.append(args[0])
    text = options.get("text") or options.get("encoding")
    return subprocess.CompletedProcess(args, 0, "" if text else b"", "" if text else b"")
subprocess.run = run
helpers = [load(name) for name in ("changelog", "decisions", "stop_scope", "release-commit")]
git_command = load("git-command")
# shutil reads os.name on import, so Windows starts only after the loads.
os.name = "nt"
for helper in helpers:
    helper.git(".", "--version")
git_command.native_path("/tmp/msg.txt")
print("\n".join(short(arg) for arg in seen))' "$lib")
same "$(printf 'git/git.EXE\ngit/git.EXE\ngit/git.EXE\ngit/git.EXE\ncyg/cygpath.EXE')" "$started" \
  "argv on Windows: changelog, decisions, stop_scope and release-commit start git, and native_path starts cygpath, by the path found on PATH"

bare=$(grep -n 'subprocess\.\(run\|Popen\|call\|check_call\|check_output\)(' "$lib"/*.py | grep -v 'program\.argv(' || true)
same "" "$bare" "each subprocess call in lib/*.py starts its program through program.argv()"

# A host that loads these files from `python3 -` has the current folder first
# on sys.path, so `import program` would load a program.py planted there.
mkdir -p "$work/planted"
printf 'print("planted program.py ran")\n' >"$work/planted/program.py"
loaded=$(cd "$work/planted" && "$py" - "$lib" <<'PY' 2>&1
import importlib.util, os, sys
for name in ("changelog", "decisions", "stop_scope", "release-commit", "git-command", "release"):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), os.path.join(sys.argv[1], name + ".py"))
    spec.loader.exec_module(importlib.util.module_from_spec(spec))
print("loaded")
PY
)
same "loaded" "$loaded" "each lib module that starts a program loads lib/program.py by its path, never a program.py in the current folder"
