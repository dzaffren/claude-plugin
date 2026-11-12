#!/usr/bin/env bash
# PreToolUse[Bash] hook: before a git commit, scan the changes it takes for secrets.
set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -I -c 'import json,sys; [s.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n") for s in (sys.stdin, sys.stdout)]; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null) || { printf '%s\n' "Blocked: could not read the hook payload, so this command was not checked." "Run it again without unusual characters." >&2; exit 2; }

# Where the command starts: the hook's cwd, which follows the session's cd.
base=$(printf '%s' "$input" | python3 -I -c 'import json,sys; [s.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n") for s in (sys.stdin, sys.stdout)]; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)
project="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -n "$base" ] || base="$project"

# Same matcher as block-dangerous.sh: the git invocations actually being run,
# falling back to the raw text when the command cannot be parsed.
git_args=$(printf '%s' "$cmd" | python3 "$(dirname "${BASH_SOURCE[0]}")/lib/git-command.py" 2>/dev/null)
if [ $? -eq 0 ]; then
  subject="$git_args"
  commit_re='^commit([[:space:]]|$)'
else
  subject="$cmd"
  commit_re='(^|[;&|[:space:]])git commit'
fi
grep -qE "$commit_re" <<<"$subject" || exit 0

# What each commit takes: the staged diff, and also every tracked change in the
# work tree for -a ("all"), or the work-tree text of each path it names
# ("paths"). The parser's lines join words with spaces, so `-m "add a.txt"`
# would read as a path there: the words come from its module. Each commit
# prints its dir, what it takes, the number of paths and the paths, each field
# NUL-ended. The directory is the one it runs in, as block-dangerous.sh works it
# out; unknown prints the start dir, the project dir and each dir the command
# names.
read_commits() {
  ZUKO_COMMAND="$cmd" python3 -I - "$(dirname "${BASH_SOURCE[0]}")/lib" "$base" "$project" <<'PY' 2>/dev/null
import importlib.util
import os
import sys

for stream in (sys.stdin, sys.stdout):
    stream.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n")

spec = importlib.util.spec_from_file_location("git_command", os.path.join(sys.argv[1], "git-command.py"))
git_command = importlib.util.module_from_spec(spec)
spec.loader.exec_module(git_command)

# git commit's options that take the next word as their value, unless it is
# attached: -mx, --message=x.
SHORT_VALUE = "mFCct"
LONG_VALUE = ("--message", "--file", "--reuse-message", "--reedit-message", "--template",
              "--author", "--date", "--cleanup", "--fixup", "--squash", "--trailer")
# The options that take work-tree changes that no path names.
LONG_ALL = ("--all", "--patch", "--interactive", "--pathspec-from-file")


def takes(args):
    """("staged" | "all" | "paths", paths) for the words after `commit`. git
    takes any unique start of a long option. A word read as a path that is not
    one adds nothing to the diff, so a word in doubt is a path."""
    scope, paths, words, after_dashes = "staged", [], iter(args), False
    for word in words:
        if git_command.is_redirection(word):
            next(words, None)               # `2>/dev/null` is the shell's
        elif after_dashes:
            paths.append(word)
        elif word == "--":
            after_dashes = True
        elif word.startswith("--"):
            name = word.split("=", 1)[0]
            if any(option.startswith(name) for option in LONG_ALL):
                scope = "all"
            elif "=" not in word and any(option.startswith(name) for option in LONG_VALUE):
                next(words, None)
        elif word.startswith("-") and word != "-":
            for at, letter in enumerate(word[1:], 1):
                if letter in "ap":
                    scope = "all"
                if letter in SHORT_VALUE:
                    if at == len(word) - 1:
                        next(words, None)
                    break
                if letter in "uS":          # -u<mode> and -S<keyid> take the rest
                    break
        else:
            paths.append(word)
    # The shell turns `$f`, a backtick, `{a,b}` or `~` into a path the text
    # does not show.
    if any(ch in path for path in paths for ch in "$`{") or any(path.startswith("~") for path in paths):
        scope = "all"
    if scope == "staged" and paths:
        scope = "paths"
    return scope, paths


try:
    tokens = git_command.tokenise(git_command.strip_heredocs(os.environ["ZUKO_COMMAND"]))
    unknown = list(dict.fromkeys(sys.argv[2:4] + git_command.candidate_dirs(tokens, sys.argv[2])))
except ValueError:
    sys.exit(3)
for where, args in git_command.invocations_with_dirs(tokens, sys.argv[2]):
    if args[:1] != ["commit"]:
        continue
    scope, paths = takes(args[1:])
    for directory in [where] if where else unknown:
        sys.stdout.write("".join(field + "\0" for field in [directory, scope, str(len(paths))] + paths))
PY
}

# The added lines of one diff, as text whatever the repo's attributes and config
# say: a -diff file, a textconv driver, an external diff, color and
# diff.relative each hide them from a plain `git diff`. grep reads a NUL byte as
# binary and then prints none of the lines. A `+++` in a file's header is not
# an added line, but one in a hunk is: `++key` added. Returns git's status.
diff_text() {   # diff_text <dir> [<git diff args>...]
  local dir=$1
  shift
  git -c diff.relative=false -C "$dir" diff --text --no-color --no-ext-diff --no-textconv "$@" </dev/null 2>/dev/null \
    | tr -d '\000' | LC_ALL=C awk '/^diff --git /{header=1} /^@@/{header=0} !header && /^\+/'
  return "${PIPESTATUS[0]}"
}

# git diff skips a file with the assume-unchanged bit, which `git ls-files -v`
# tags in lower case, but git commit <path> takes its work-tree text: diff the
# index's copy against it.
assumed_text() {   # assumed_text <dir> <paths>...
  local dir=$1 entry
  shift
  while IFS= read -r -d '' entry; do
    case ${entry:0:1} in [a-z]) ;; *) continue ;; esac
    git -C "$dir" cat-file blob ":${entry:2}" >"$blob" 2>/dev/null
    diff_text "$dir" --no-index -- "$blob" "${entry:2}"
  done < <(git -C "$dir" ls-files -z -v -- "$@" 2>/dev/null)
}

blob=$(mktemp) || { echo "Blocked: could not make a temp file, so this commit was not checked." >&2; exit 2; }
trap 'rm -f "$blob"' EXIT

added=""
records=0
while IFS= read -r -d '' dir && IFS= read -r -d '' scope && IFS= read -r -d '' count; do
  records=$((records + 1))
  paths=()
  while [ "$count" -gt 0 ] && IFS= read -r -d '' path; do
    paths+=("$path")
    count=$((count - 1))
  done
  added+=$(diff_text "$dir" --cached)$'\n'
  case $scope in
    all) added+=$(diff_text "$dir")$'\n' ;;
    paths)
      # A word git refuses as a path fails the whole diff: read all instead.
      text=$(diff_text "$dir" -- "${paths[@]}") || text=$(diff_text "$dir")
      added+=$text$'\n'$(assumed_text "$dir" "${paths[@]}")$'\n' ;;
  esac
done < <(read_commits)

# Unparsed, or no commit read: everything a commit could take, in both the
# start and the project dir — never less than the project dir alone.
if [ "$records" -eq 0 ]; then
  while IFS= read -r dir; do
    added+=$(diff_text "$dir" --cached)$'\n'$(diff_text "$dir")$'\n'
  done <<<"$base"$'\n'"$project"
fi
[ -z "${added//$'\n'/}" ] && exit 0

pattern='AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|glpat-[A-Za-z0-9_-]{20}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9_-]{20,}|AIza[A-Za-z0-9_-]{35}|(password|passwd|secret|api[_-]?key|access[_-]?token)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'[:space:]]{12,}'

hits=$(printf '%s\n' "$added" | grep -aiEn "$pattern" | head -5 || true)
if [ -n "$hits" ]; then
  {
    echo "Blocked: the changes this commit takes look like they contain secrets:"
    echo "$hits"
    echo "Take the secret out of the file, or leave the file out of the commit: unstage it (git restore --staged <file>), and do not name it or use -a. Move the secret to an untracked env file, then commit again. If this is a false positive, tell the user what matched and let them decide."
  } >&2
  exit 2
fi
exit 0
