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
  "$py" -c 'import os, sys; sys.path.insert(0, sys.argv[1]); import program
'"$short"'
exts = [e for e in sys.argv[3].split(";") if e]
print(short(program.find(sys.argv[2], os.pathsep.join(sys.argv[4:]), exts)))' "$lib" "$@"
}

argv_on() {  # argv_on <os.name> <PATH> <arg>...: argv() of the args, one per line
  local name=$1 path=$2
  shift 2
  PATH="$path" PATHEXT=".EXE" "$py" -c 'import os, sys; sys.path.insert(0, sys.argv[1]); import program
'"$short"'
os.name = sys.argv[2]
print("\n".join(short(arg) for arg in program.argv(sys.argv[3:])))' "$lib" "$name" "$@"
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
same "$(printf 'gh\napi')" "$(argv_on nt "$work/empty:$work/sh" gh api)" \
  "argv on Windows: a name not on PATH is given back, so the caller's not-installed path runs"
same "$(printf 'gh\napi')" "$(argv_on nt "$work/one" gh api)" \
  "argv on Windows: a #! script with no bash on PATH is given back unchanged"
